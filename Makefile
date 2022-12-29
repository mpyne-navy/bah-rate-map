# Makefile to drive assembly of the TopoJSON data needed by the index.html
# Dependencies:
#   * NodeJS,
#   * unzip command line tool,
#   * ogr2ogr (from GDAL),
#   * Perl interpreter installed
#   * Python3 installed (if you want "make serve" to work)
# You must download cb_2020_us_zcta520_500k.zip from U.S. Census Bureau,
#   https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_zcta520_500k.zip
#   (the Makefile will download it if you have wget)
# You must download DoD BAH Rates for 2023 (in ASCII file type).
#   (see https://www.travel.dod.mil/Allowances/Basic-Allowance-for-Housing/BAH-Rate-Lookup/)

TOPOMERGE=./node_modules/topojson-client/bin/topomerge
TOPOQUANTIZE=./node_modules/topojson-client/bin/topoquantize
TOPOSIMPLIFY=./node_modules/topojson-simplify/bin/toposimplify
GEO2TOPO=./node_modules/topojson-server/bin/geo2topo
IMPUTE_RATES=./impute-rates.pl

.PHONY: all serve clean

all: us_dod_mha.topo.json

serve: index.html all bahwo23.txt bahw23.txt
	python3 -m http.server

us_dod_mha-detail-heavy.topo.json: us_zcta500-wbah-simplified.topo.json $(TOPOMERGE)
	$(TOPOMERGE) us_dod_mha=us_zcta500.geo -o $@ -k 'd.properties.DOD_BAH_MHA' $<

us_zcta500-simplified.topo.json: us_zcta500.topo.json $(TOPOSIMPLIFY)
	$(TOPOSIMPLIFY) -o $@ -F -P 0.02 $<

us_zcta500-wbah-simplified.topo.json: us_zcta500-simplified.topo.json sorted_zipmha23.txt $(IMPUTE_RATES)
	$(IMPUTE_RATES) $< $@

us_dod_mha.topo.json: us_dod_mha-detail.topo.json $(TOPOQUANTIZE)
	$(TOPOQUANTIZE) -o $@ 10000 $<

us_dod_mha-detail.topo.json: us_dod_mha-detail-heavy.topo.json strip-zctas.js
	node strip-zctas.js $< $@ us_zcta500.geo

us_zcta500.topo.json: us_zcta500.geo.json us_nation_5m.geo.json $(GEO2TOPO)
	$(GEO2TOPO) -o $@ us_zcta500.geo=us_zcta500.geo.json us_nation=us_nation_5m.geo.json

us_nation_5m.geo.json: cb_2020_us_nation_5m.shp cb_2020_us_nation_5m.shx cb_2020_us_nation_5m.dbf
	ogr2ogr -f GeoJSON $@ $<

us_zcta500.geo.json: cb_2020_us_zcta520_500k.shp cb_2020_us_zcta520_500k.shx cb_2020_us_zcta520_500k.dbf
	ogr2ogr -f GeoJSON $@ $<

# Needed NPM packages
$(GEO2TOPO) $(TOPOMERGE) $(TOPOQUANTIZE) $(TOPOSIMPLIFY): package.json
	npm install

# Census data
cb_2020_us_zcta520_500k.shp cb_2020_us_zcta520_500k.shx cb_2020_us_zcta520_500k.dbf: cb_2020_us_zcta520_500k.zip
	unzip -DD -n $< $@

cb_2020_us_zcta520_500k.zip:
	wget https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_zcta520_500k.zip

# We use the 5m scale nation outline because this doesn't need to be high fidelity
cb_2020_us_nation_5m.zip: cb_2020_us_all_5m.zip
	unzip -DD -n $< $@

cb_2020_us_nation_5m.shp cb_2020_us_nation_5m.shx cb_2020_us_nation_5m.dbf: cb_2020_us_nation_5m.zip
	unzip -DD -n $< $@

cb_2020_us_all_5m.zip:
	wget https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_all_5m.zip

# BAH MHA data
sorted_zipmha23.txt bahw23.txt bahwo23.txt: BAH-ASCII-2023.zip
	unzip -DD -n $< $@

clean:
	rm -f us*.json
	rm -f *.txt
	rm -f cb_*.{shp,dbf,shx}
	rm -rf node_modules

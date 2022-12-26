# Makefile to drive assembly of the TopoJSON data needed by the index.html
# Dependencies:
#   * NodeJS,
#   * unzip command line tool,
#   * ogr2ogr (from GDAL),
#   * Perl interpreter installed
#   * Python3 installed (if you want "make serve" to work)
# You must download cb_2018_us_zcta510_500k.zip from U.S. Census Bureau
#   (see https://www2.census.gov/geo/tiger/GENZ2018/shp/)
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

us_dod_mha-detail.topo.json: us_zcta500-wbah-simplified.topo.json $(TOPOMERGE)
	$(TOPOMERGE) us_dod_mha=us_zcta500.geo -o $@ -k 'd.properties.DOD_BAH_MHA' $<

us_zcta500-simplified.topo.json: us_zcta500.topo.json $(TOPOSIMPLIFY)
	$(TOPOSIMPLIFY) -o $@ -F -P 0.05 $<

us_zcta500-wbah-simplified.topo.json: us_zcta500-simplified.topo.json sorted_zipmha23.txt $(IMPUTE_RATES)
	$(IMPUTE_RATES) $< $@

us_dod_mha.topo.json: us_dod_mha-detail.topo.json $(TOPOQUANTIZE)
	$(TOPOQUANTIZE) -o $@ 10000 $<

us_zcta500.topo.json: us_zcta500.geo.json $(GEO2TOPO)
	$(GEO2TOPO) -o $@ $<

us_zcta500.geo.json: cb_2018_us_zcta510_500k.shp cb_2018_us_zcta510_500k.shx cb_2018_us_zcta510_500k.dbf
	ogr2ogr -f GeoJSON $@ $<

$(GEO2TOPO) $(TOPOMERGE) $(TOPOQUANTIZE) $(TOPOSIMPLIFY): package.json
	npm install

cb_2018_us_zcta510_500k.shp cb_2018_us_zcta510_500k.shx cb_2018_us_zcta510_500k.dbf: cb_2018_us_zcta510_500k.zip
	unzip -DD -n $< $@

sorted_zipmha23.txt bahw23.txt bahwo23.txt: BAH-ASCII-2023.zip
	unzip -DD -n $< $@

clean:
	rm -f us*.json
	rm -f *.txt
	rm -f cb_*.{shp,dbf,shx}
	rm -rf node_modules

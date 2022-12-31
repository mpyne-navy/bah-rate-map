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

# This is the generated file that we serve to users. Two other files are served as-is.
all: us_dod_mha.topo.json

# Local web server, accessible at http://localhost:8000/
serve: index.html us_dod_mha.topo.json bahwo23.txt bahw23.txt
	python3 -m http.server

#
# INTERMEDIATE GENERATED FILES
#
# These rules are ordered going from the final product to the steps that build
# each needed intermediate output.  The rules to bring in the NPM packages are
# at the bottom, however.
#

# We build the final result by 'quantizing' the detailed topological data to
# reduce file size by aligning coordinates onto a grid.  The 10,000 number
# gives 10,000 possible values per axis and seems to give a good balance
# between quality and file size.
us_dod_mha.topo.json: us_dod_mha-detail.topo.json $(TOPOQUANTIZE)
	$(TOPOQUANTIZE) -o $@ 10000 $<

# BAH MHA data, which is downloaded directly by the client Javascript which
# merges with the MHA map data on the client-side.
# The same ZIP file provides "sorted_zipmha23.txt" which we use in a later rule.
#
# TODO: Consider pre-merging with the TopoJSON data? Seems like the result
# would be larger but having fewer GET requests may still be worth it overall.
# TODO: Add wget rule for BAH-ASCII-2023.zip
sorted_zipmha23.txt bahw23.txt bahwo23.txt: BAH-ASCII-2023.zip
	unzip -DD -n $< $@

# The detailed topological data is reduced in size somewhat by removing the
# now-unneeded TopoJSON data that still contains the individual ZCTAs (since
# they've been merged into MHAs which is what we're after).
us_dod_mha-detail.topo.json: us_dod_mha-detail-heavy.topo.json strip-zctas.js
	node strip-zctas.js $< $@ us_zcta

# The merge step creates a new TopoJSON object in the output file containing
# ZCTAs merged into their corresponding MHAs, and retains the old layer. We'll
# strip the old data later.
us_dod_mha-detail-heavy.topo.json: us_zcta520-wbah-simplified.topo.json $(TOPOMERGE)
	$(TOPOMERGE) us_dod_mha=us_zcta -o $@ -k 'd.properties.DOD_BAH_MHA' $<

# Once we've simplified the input data to reduce file size (and therefore
# processing time to handle), we go ahead and add MHA assignments to ZCTA
# geographic features, where there is an MHA defined. We use an auxiliary
# script for this.
us_zcta520-wbah-simplified.topo.json: us_zcta520-simplified.topo.json sorted_zipmha23.txt $(IMPUTE_RATES)
	$(IMPUTE_RATES) $< $@

# The U.S. ZCTA TopoJSON is still quite heavyweight. We run a simplification
# pass early on to reduce the complexity of the map data to reduce effort in
# later computation steps.
us_zcta520-simplified.topo.json: us_zcta520.topo.json $(TOPOSIMPLIFY)
	$(TOPOSIMPLIFY) -o $@ -F -P 0.02 $<

# We convert the input GeoJSON data into a smaller "TopoJSON" format that
# shares data for common borders between geographic features. The JavaScript on
# the client will convert it back to GeoJSON before presenting it as SVG data.
# GeoJSON allows us to combine 2 GeoJSON files into one TopoJSON output file
# (separate layers), which we take advantage of to include a U.S. nation map
# overlay.
us_zcta520.topo.json: us_zcta520.geo.json us_nation_5m.geo.json $(GEO2TOPO)
	$(GEO2TOPO) -o $@ us_zcta=us_zcta520.geo.json us_nation=us_nation_5m.geo.json

# The next two rules use GDAL's ogr2ogr to convert the U.S. Census Bureau's
# "shapefile" format geographic features (U.S. nation outline and ZCTAs) into
# GeoJSON data which we can process the rest of the way.
# TODO: Turn this into a make pattern rule.
us_nation_5m.geo.json: cb_2020_us_nation_5m.shp cb_2020_us_nation_5m.shx cb_2020_us_nation_5m.dbf
	ogr2ogr -f GeoJSON $@ $<

us_zcta520.geo.json: cb_2020_us_zcta520_500k.shp cb_2020_us_zcta520_500k.shx cb_2020_us_zcta520_500k.dbf
	ogr2ogr -f GeoJSON $@ $<

# The next two rules extract the "shapefile" data from the ZIP files provided
# by U.S. Census Bureau website.
# TODO: Turn this into a make pattern rule.
cb_2020_us_zcta520_500k.shp cb_2020_us_zcta520_500k.shx cb_2020_us_zcta520_500k.dbf: cb_2020_us_zcta520_500k.zip
	unzip -DD -n $< $@

cb_2020_us_nation_5m.shp cb_2020_us_nation_5m.shx cb_2020_us_nation_5m.dbf: cb_2020_us_nation_5m.zip
	unzip -DD -n $< $@

# The next three rules are used to download the needed ZIP files from Census
# Bureau website. The nation data is not available directly but is pulled from
# a broader dataset.
cb_2020_us_zcta520_500k.zip:
	wget https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_zcta520_500k.zip

# We use the 5m scale nation outline because this doesn't need to be high fidelity
cb_2020_us_nation_5m.zip: cb_2020_us_all_5m.zip
	unzip -DD -n $< $@

cb_2020_us_all_5m.zip:
	wget https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_all_5m.zip

# Finally, the NPM rule ensures that needed Node packages are installed to be
# used by Make. To add new packages you need to update the package.json
# (directly or by using `npm add` as normal).
$(GEO2TOPO) $(TOPOMERGE) $(TOPOQUANTIZE) $(TOPOSIMPLIFY): package.json
	npm install

# This rule removes most intermediate files but doesn't touch the downloaded
# ZIP data so that you don't hammer the servers.
clean:
	rm -f us*.json
	rm -f *.txt
	rm -f cb_*.{shp,dbf,shx}
	rm -rf node_modules

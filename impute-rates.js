// Combine BAH data into the TopoJSON ZCTA data so that
// topomerge can combine like-MHA assignments into MHA
// geographic features.

const fs      = require('fs').promises;
const process = require('process');

// node, this script, input, output, obj-to-remove
if (process.argv.length != 4) {
    console.error(`Usage ${argv[1]} <input-file> <output-file>`);
    return 1;
}

const in_filename  = process.argv[2];
const out_filename = process.argv[3];
const TOPOJSON_ZCTA_LAYER = 'us_zcta'; // must match layer name in TopoJSON input

let zctaJson = ''; // main JSON data to fill in

async function loadMHAAssignmentData()
{
    const mha_lines = await fs.readFile("sorted_zipmha23.txt", 'utf-8');

    let mha_assigns    = new Set();
    let used_zip_codes = new Map;

    // ugly to read whole file in at once but the dataset isn't very large here
    for (const line of mha_lines.split(/\r?\n/)) {
        const [zip, mha_id] = line.split(' ');
        if (!zip || !mha_id) {
            throw new Error(`Undefined ZIP or MHA entry ${line}`);
        }

        mha_assigns.add(mha_id);
        used_zip_codes.set(zip, mha_id);
    }

    return [mha_assigns, used_zip_codes];
}

async function loadZCTAData(zctaFile)
{
    const zctaBuf = await fs.readFile(zctaFile);

    return JSON.parse(zctaBuf);
}

function buildAugmentedZCTAData(zctaJson, mhas, zips)
{
    let zctaUpdateCount = 0;
    const zctaTotal = zctaJson.objects[TOPOJSON_ZCTA_LAYER].geometries.length;

    for (let zcta of zctaJson.objects[TOPOJSON_ZCTA_LAYER].geometries) {
        const zcta_zip = zcta.properties.GEOID20; // 5-digit ZIP code, name changes in datasets sometimes

        if (zips.has(zcta_zip)) {
            zcta.properties.DOD_BAH_MHA = zips.get(zcta_zip);
            zctaUpdateCount++;
        } else {
            zcta.properties.DOD_BAH_MHA = 'unused';
        }
    }

    console.log(`${zctaUpdateCount} / ${zctaTotal} ZCTAs assigned to an MHA`);
    console.log(`${zctaUpdateCount} / ${zips.size} MHA ZIP codes assigned to a ZCTA`);

    if (zctaUpdateCount == 0) {
        throw new Error("Something must have gone wrong, aborting.");
    }

    return zctaJson;
}

const mhaPromise  = loadMHAAssignmentData();
const zctaPromise = loadZCTAData(in_filename);

Promise.all([mhaPromise, zctaPromise])
    .then(([mhaResults, zctaResults]) => {
        const [mhas, zips] = mhaResults;

        console.log(`${mhas.size} MHAs defined across ${zips.size} ZIP codes`);
        console.log(`${zctaResults.objects.us_zcta.geometries.length} ZCTAs loaded`);

        const mergedZcta = buildAugmentedZCTAData(zctaResults, mhas, zips);

        // write results
        return fs.writeFile(out_filename, JSON.stringify(mergedZcta));
    }).catch((err) => {
        console.warn(`Caught error ${err}`);
        process.exit(1);
    });

// Remove the embedded ZCTA objects that are left in by topojson-merge

const fs = require('fs').promises;
const process = require('process');
const argv = process.argv;

// node, this script, input, output, obj-to-remove
if (argv.length != 5) {
    console.error(`Usage ${argv[1]} <input-file> <output-file> <obj-to-remove>`);
    return 1;
}

async function mainWork() {
    const topoJson = await fs.readFile(argv[2]);
    let topoData = JSON.parse(topoJson);
    delete topoData.objects[argv[4]];

    // topomerge mapped the key to the 'id' field so we no longer need 'properties'
    for (let feature of topoData.objects.us_dod_mha.geometries) {
        delete feature.properties;
    };

    await fs.writeFile(argv[3], JSON.stringify(topoData));
    console.log(`${argv[4]} removed`);
};

mainWork();

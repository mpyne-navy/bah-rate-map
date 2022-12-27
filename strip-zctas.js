// Remove the embedded ZCTA objects that are left in by topojson-merge

const fs = require('fs/promises');
const process = require('process');
const argv = process.argv;

// node, this script, input, output, obj-to-remove
if (argv.length != 5) {
    console.error(`Usage ${argv[1]} <input-file> <output-file> <obj-to-remove>`);
    return 1;
}

let objToWrite;

async function mainWork() {
    await fs.readFile(argv[2]).then((data) => {
        const topoJson = JSON.parse(data);
        delete topoJson.objects[argv[4]];
        objToWrite = topoJson;
    });

    await fs.writeFile(argv[3], JSON.stringify(objToWrite)).then((done) => {
        console.log(`${argv[4]} removed`);
    });
};

mainWork();
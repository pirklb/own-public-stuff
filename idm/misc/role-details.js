const fs = require('fs');
const idm = require('./idm.js');
const simulate = false;

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function main(fn = '/tmp/r10-raw.json', skipBlocks = -1) {
    console.log('initializing');
    //idm.initIdm({ debug: true });
    idm.initIdm();
    console.log('login');
    await idm.idmLogin();
    console.log('getting it roles');
    let r10;
    if (!fs.existsSync(fn)) {
        r10 = await idm.invokeIdmRest('IDMProv/rest/catalog/roles/listV2?nextIndex=1&q=*&sortOrder=asc&sortBy=name&roleLevel=10&size=7000', 'GET', {}, {}, 'roles');
        const j10 = JSON.stringify(r10, null, 2);
        fs.writeFileSync('/tmp/r10-raw.json', j10, { encoding: "utf8" });
    }
    r10 = JSON.parse(fs.readFileSync(fn, { encoding: "utf8" }));
    const arrRoles = [];
    console.log(`got ${r10.length} roles back, getting details ...`);
    let blockIndex = 0;
    let block = 0;
    let json = '';
    for (let ndx = 0; ndx < r10.length; ndx++) {
        blockIndex++;
        if (blockIndex > 200) {
            blockIndex = 0;
            block++;
            if (skipBlocks < block) {
                json = JSON.stringify(arrRoles, null, 2);
                fs.writeFileSync(`/tmp/r10-${block}.json`, json, { encoding: "utf8" });
                console.log(`written new data file - /tmp/r10-${block}.json`);
            }
        }
        if (skipBlocks < block) {
            let r = r10[ndx];
            let id = r.id;
            console.log(`${ndx}. Processing ${id}`);
            let b = `{"id":"${id}"}`;
            let bAssignments = `{"dn":"${id}"}`
            if (!id.toLowerCase().startsWith('cn=wurmlogin_')) {
                if (!simulate) {
                    let res = await idm.invokeIdmRest('IDMProv/rest/catalog/roles/mappedResources/list?nextIndex=1&size=50&q=*&driverID=', 'POST', b, {}, '');
                    let parents = await idm.invokeIdmRest('IDMProv/rest/catalog/roles/parentRoles/list?size=50&q=*&nextIndex=1', 'POST', b, {}, '');
                    let assignments = await idm.invokeIdmRest('IDMProv/rest/catalog/roles/role/assignments/v2?nextIndex=1&q=&sortOrder=asc&sortBy=name&size=500', 'POST', bAssignments, {}, '');
                    arrRoles.push({ id, res, parents, assignments });
                }
                await sleep(250);
            } else {
                console.log(`************************** Skipping ${id} ***`);
            }
        }
    }
    if (!simulate) {
        const json = JSON.stringify(arrRoles, null, 2);
        fs.writeFileSync('/tmp/r10-final.json', json, { encoding: "utf8" });
    }
    await idm.idmLogout();
}

console.log('calling main');
main('/tmp/r10-raw.json', 15);
console.log('finished');

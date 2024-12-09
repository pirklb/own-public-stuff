const { getAuthHeader, idmLogin, useRefreshToken, idmLogout, invokeIdmRest, addIdmRoleMember, removeIdmRoleMember, getIdmRoleMember, initIdm } = require("./idm.js");
const fs = require('node:fs');
const path=require('path');
const db = require('./db.js');

version = '24.801.3'
// 24.729.1 - Initialversion
// 24.730.1 - Umgestellt auf require statt import
// 24.801.1 - Owner der Ownermanaged Rollen auch ermitteln und Export der Ergebnisse als JSON
// 24.801.2 - Manche Rollen haben keinen Owner (mehr)
// 24.801.3 - Bei den Mitarbeitern wurde ebenfalls das Rollen-JSON exportiert

async function main() {
// #region idmConfig
    const idmConfig = initIdm();

    // doDebug && console.log('service user=', idmConfig['IDM_SERVICE_USERNAME']);
    // doDebug && console.log('service password=', idmConfig['IDM_SERVICE_PASSWORD']);

    // doDebug && console.log('IDM_SERVER=', idmConfig['IDM_SERVER']);
    // doDebug && console.log('IDM_TOKEN_ENDPOINT=', idmConfig['IDM_TOKEN_ENDPOINT']);
    // doDebug && console.log(`IDM_CLIENTSECRET='${idmConfig.IDM_CLIENTSECRET}'`);
// #endregion
  const { accessToken, refreshToken } = await idmLogin('cn=rest-reader,ou=sa,o=idvault','F#14Tz4V!UipWICWObf');
  const folderName='/home/pirklb/node/idm-api';

  // omro: allKey fuer Javascript='roles'
  console.log('retrieving owner managed roles ...');
  const omro=await invokeIdmRest('IDMProv/rest/catalog/roles/listV2?categoryKeys=owner-managed&size=1000','GET',{},{},'roles');
  console.log(`got ${omro?.length || '???'} roles back`);

  // Owner fuer jede Rolle ermitteln ...
  let leereOwnerManagedRollen=0;
  for (let aktRolle of omro) {
    let body={roles:{id:aktRolle.id}};
    const ownerInfo=await invokeIdmRest('IDMProv/rest/catalog/roles/roleV2','POST',body,{});
    if (ownerInfo.roles[0]?.owners) {
      const owners=ownerInfo.roles[0].owners.map(o => o.id);
      aktRolle['owners']=owners;
    } else {
      leereOwnerManagedRollen++;
      console.log('Keine Owner???, ',aktRolle.id);
    }
  }
  leereOwnerManagedRollen && console.log(leereOwnerManagedRollen,' haben keinen Owner!');
  const jOmro=JSON.stringify(omro);
  fs.writeFileSync(path.resolve((typeof __dirname === 'undefined' ? folderName : __dirname),'./data/idm-owner-mgmt-roles.json'),jOmro,{flush:true});

  // ma: allKey fuer Javascript='usersList'
  console.log('retrieving employees ...');
  const maRequestUrl='IDMProv/rest/access/users/list?q=*&clientId=1&size=1000&sortOrder=asc&sortBy=LastName&searchAttr=LastName,FirstName,Email,cN,workforceID,DirXML-NTAccountName&columnCustomization=true&filter=LastName,FirstName,Email,cN,workforceID,TelephoneNumber,DirXML-NTAccountname,itdidmHRID,itdprovLocation,itdprovCompany&advSearch=cN:p_*';
  const ma=await invokeIdmRest(maRequestUrl,'GET',{},{},'usersList');
  console.log(`got ${ma?.length || '???'} employees back`);
  const jMa=JSON.stringify(ma);
  fs.writeFileSync(path.resolve((typeof __dirname === 'undefined' ? folderName : __dirname),'./data/idm-all-mas.json'),jMa,{flush:true});

  console.log(`current refreshToken=${idmConfig["refreshToken"]}`);
  await idmLogout(idmConfig["refreshToken"]);

}

async function dbtest() {
  const res = await db.query('select * from public.employees')
  console.log(res);
  //return(res);
}

dbtest();
//main();

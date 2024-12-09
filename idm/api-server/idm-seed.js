const { getAuthHeader, idmLogin, useRefreshToken, idmLogout, invokeIdmRest, addIdmRoleMember, removeIdmRoleMember, getIdmRoleMember, initIdm } = require("./idm.js");
const fs = require('node:fs');
const path = require('path');
const db = require('./db.js');

version = '24.1203.1'
// 24.729.1 - Initialversion
// 24.730.1 - Umgestellt auf require statt import
// 24.801.1 - Owner der Ownermanaged Rollen auch ermitteln und Export der Ergebnisse als JSON
// 24.801.2 - Manche Rollen haben keinen Owner (mehr)
// 24.801.3 - Bei den Mitarbeitern wurde ebenfalls das Rollen-JSON exportiert
// 24.802.1 - PostgreSQL eingebunden (im Moment in einer Test-Funktion dbtest)
// 24.805.1 - Owner (nur die HRIDs) als Kommaseparierte Liste bei den Rollen merken
// 24.805.2 - Fehlerkorrektur bei Ownerermittlung
// 24.805.3 - Speichern der Owner Managed Rollen in PostgreSQL
// 24.805.4 - Längenbegrenzung und try catch beim Einfügen von OwnerManagedRollen im PostgreSQL
// 24.805.5 - Mitarbeiterdaten ebenfalls in PostgreSQL speichern
// 24.805.6 - Steuern, ob Rollen und/oder Mitarbeiter verarbeitet werden sollen (Parameter für main)
// 24.805.7 - Tippfehler bei itdprovLocation
// 24.806.1 - Erweiterung der Parameter bei main, so dass auch gar kein Parameter angegeben werden muss, also main() möglich ist
// 24.807.1 - Erweiterung um employeeStatus und Korrektur REST-Url
// 24.807.2 - Erweiterung getPrimaryAttribute um $ oder value
// 24.808.1 - Erweiterung um created/modified bei Usern
// 24.808.2 - Erweiterung um created/modified bei ownerManagedRoles
// 24.812.1 - Erweiterung um Owner für Ordner (wobei die Rolle ebenfalls die ownerManagedRoles Kategorie haben muss)
// 24.823.1 - Erweiterung um IDM Admins für alle Rollen
// 24.902.1 - dn, cn, employeeStatus, Mailadresse, Location, Mandant (und sAMAccountname) in Kleinbuchstaben speichern
// 24.930.1 - routeId (id der Rolle - aber nur diese Zeichen davon _-a-zA-Z0-9)
// 24.1104.1 - Rollen und Employees, die seit mehr als 7 Tagen nicht mehr geändert wurden, werden in der PostgreSQL-Datenbank gelöscht  
// 24.1203.1 - Fehlerbehandlung beim Schreiben der JSON-Dateien (die eigentlich nicht mehr notwendig sind)
const folderOwner = [
  // id in regexp kompatibler Form angeben
  { id: '.*,cn=datenabo,cn=level10,cn=roledefs,cn=roleconfig,cn=appconfig,cn=userapplication,cn=driverset,o=system', owner: 'p_19875607,p_19845229,p_19870239', },
  { id: '.*,cn=wurm,cn=level10,cn=roledefs,cn=roleconfig,cn=appconfig,cn=userapplication,cn=driverset,o=system', owner: 'p_19873788,p_19875439,p_20458263,p_457494491', },
  { id: '.*,cn=dwh-pers,cn=level10,cn=roledefs,cn=roleconfig,cn=appconfig,cn=userapplication,cn=driverset,o=system', owner: 'p_19533559' },
  { id: '.*,o=system', owner: 'p_19849475,p_19852495,p_466554691', }
]
function getPrimaryAttribute(primaryAttributes, attrName, standard = '???') {
  let attr = primaryAttributes.find(p => p.key === attrName);
  if (!attr) return standard;
  let v = attr?.attributeValues?.map(av => {
    // return value of attribute $ or if not present return value of attribute value
    return av['$'] || av['value'];
  });
  if (Array.isArray(v)) v = v[0];
  return v || standard;
}
async function getSamAccountName(email) {
  // psu ist nicht von überall errreichbar ...
  return email; // temporaer die Mailadresse retournieren - solange man den Benutzernamen noch nicht auslesen kann

  const url = `https://psu.lkw-walter.com/activedirectory/user/${email}`;
  const { sAMAccountname } = await axios.get(`https://psu.lkw-walter.com/activedirectory/user/${email}`);
  console.log(`${email} = ${sAMAccountname}`);
  return sAMAccountname;
}

async function main({ roles = true, employees = true } = {}) {
  // #region idmConfig
  const idmConfig = initIdm();

  // doDebug && console.log('service user=', idmConfig['IDM_SERVICE_USERNAME']);
  // doDebug && console.log('service password=', idmConfig['IDM_SERVICE_PASSWORD']);

  // doDebug && console.log('IDM_SERVER=', idmConfig['IDM_SERVER']);
  // doDebug && console.log('IDM_TOKEN_ENDPOINT=', idmConfig['IDM_TOKEN_ENDPOINT']);
  // doDebug && console.log(`IDM_CLIENTSECRET='${idmConfig.IDM_CLIENTSECRET}'`);
  // #endregion
  const { accessToken, refreshToken } = await idmLogin('cn=rest-reader,ou=sa,o=idvault', 'F#14Tz4V!UipWICWObf');
  const folderName = '/home/pirklb/node/idm-api';

  // #region owner managed roles
  // omro: allKey fuer Javascript='roles'
  if (roles) {
    let rolesErrors = 0;
    console.log('retrieving owner managed roles ...');
    const omro = await invokeIdmRest('IDMProv/rest/catalog/roles/listV2?categoryKeys=owner-managed&size=1000', 'GET', {}, {}, 'roles');
    console.log(`got ${omro?.length || '???'} roles back`);

    // Owner fuer jede Rolle ermitteln ...
    let leereOwnerManagedRollen = 0;
    for (let aktRolle of omro) {
      let body = { roles: { id: aktRolle.id } };
      const ownerInfo = await invokeIdmRest('IDMProv/rest/catalog/roles/roleV2', 'POST', body, {});
      if (ownerInfo.roles[0]?.owners) {
        let ownerIds = [];
        for (let owner of ownerInfo.roles[0].owners) {
          ownerIds.push(owner.id.match(/cn=(?<id>p_\d+),.*/)?.groups?.['id']);
        }
        //const owners=ownerInfo.roles[0].owners.map(o => o.id);
        aktRolle['owners'] = ownerIds.join(',');
      } else {
        leereOwnerManagedRollen++;
        aktRolle['owners'] = '';
        console.log('Keine Owner???, ', aktRolle.id);
      }
      aktRolle['routeId'] = aktRolle.id.replace(/[^a-zA-Z0-9\-_]/g, '').replace(/cnroledefscnroleconfigcnappconfigcnuserapplicationcndriversetosystem$/, '');
      aktRolle['owners'] = [aktRolle.owners, // die bisherigen Owner
      ...(folderOwner // spreade die folderOwner eines eventuell passenden Eintrags in folderOwner
        .filter(e => // passend heißt:
          aktRolle.id.match(`${e.id}`)) // die id der aktuellen Rolle passt zum aktuellen Eintrag in folderOwner
        .map(e => e.owner))] // von einem Treffer hole genau das owner-Attribut
        .filter(e => e) // entferne leere Elemente (entweder, weil bisher keine Owner gefunden wurden oder weil es keinen passenden Eintrag in folderOwner fuer diese Rolle gibt)
        .join(','); // füge die Array-Elemente mit , wieder zusammen
      const queryText = 'INSERT INTO public."ownerManagedRoles" (id,name,description,level,owners,categories,created,modified,"routeId") values ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, $7) ON CONFLICT (id) DO UPDATE SET name = $2, description = $3, level = $4, owners = $5, categories = $6, modified = CURRENT_TIMESTAMP, "routeId" = $7';
      const queryParams = [(aktRolle.id).substring(0, 249), aktRolle.name.substring(0, 69), aktRolle.description, aktRolle.level, aktRolle.owners.substring(0, 149), JSON.stringify(aktRolle.categories), aktRolle.routeId.substring(0, 149)]
      try {
        await db.query(queryText, queryParams);
      } catch (e) {
        rolesErrors++;
        console.log(`Error inserting/updating role '${aktRolle.id}': ${e.message}`);
      }
      // #region alte OwnerManagedRollen loeschen
      if (rolesErrors > Math.floor(omro.length * 0.1)) {
        // max 10% Fehler, daher alte Einträge löschen
        const queryText = 'DELETE FROM public."ownerManagedRoles" WHERE modified < CURRENT_TIMESTAMP - INTERVAL \'7 days\''; // 7 Tage
        try {
          await db.query(queryText);
        } catch (e) {
          console.log(`Error deleting old roles: ${e.message}`);
        }
      }
      // #endregion

    }
    leereOwnerManagedRollen && console.log(leereOwnerManagedRollen, ' haben keinen Owner!');
    const jOmro = JSON.stringify(omro);
    try {
      fs.writeFileSync(path.resolve((typeof __dirname === 'undefined' ? folderName : __dirname), './data/idm-owner-mgmt-roles.json'), jOmro, { flush: true });
    } catch (e) {
      console.log(`Error writing file for owner-managed-roles: ${e.message}`);
    }
  }
  // #endregion

  // #region employees
  if (employees) {
    let employeeErrors = 0;
    // ma: allKey fuer Javascript='usersList'
    console.log('retrieving employees ...');
    const maRequestUrl = 'IDMProv/rest/access/users/list?clientId=1&size=1000&advSearch=cN:p_*&columnCustomization=true&filter=LastName,FirstName,Email,cN,workforceID,TelephoneNumber,DirXML-NTAccountname,itdidmHRID,itdprovLocation,itdprovCompany,employeeStatus';
    const ma = await invokeIdmRest(maRequestUrl, 'GET', {}, {}, 'usersList');
    console.log(`got ${ma?.length || '???'} employees back`);
    for (let aktMa of ma) {
      let primaryAttributes, dn, fullName, firstName, lastName, email, cn, workforceID, telephoneNumber, itdidmHRID, location, operationalTenant, employeeStatus, queryText, queryParams
      try {
        queryText = 'INSERT INTO public.employees (dn,"fullName","firstName","lastName",email,cn,"workforceID","telephoneNumber","itdidmHRID",location,"operationalTenant","employeeStatus", created,modified) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ON CONFLICT (dn) DO UPDATE SET "fullName" = $2, "firstName" = $3, "lastName" = $4, email = $5, cn = $6, "workforceID" = $7, "telephoneNumber" = $8, "itdidmHRID" = $9, location  = $10, "operationalTenant" = $11, "employeeStatus" = $12, modified = CURRENT_TIMESTAMP'
        primaryAttributes = aktMa.primaryAttributes;
        dn = aktMa.dn.substring(0, 49).toLowerCase();
        fullName = aktMa.fullName.substring(0, 49);
        firstName = getPrimaryAttribute(primaryAttributes, 'FirstName', '???').substring(0, 19);
        lastName = getPrimaryAttribute(primaryAttributes, 'LastName', '???').substring(0, 19);
        email = getPrimaryAttribute(primaryAttributes, 'Email', '???').substring(0, 49).toLowerCase();
        employeeStatus = getPrimaryAttribute(primaryAttributes, 'employeeStatus', '???').substring(0, 14).toLowerCase();
        cn = getPrimaryAttribute(primaryAttributes, 'cN', '???').substring(0, 19).toLowerCase();
        workforceID = getPrimaryAttribute(primaryAttributes, 'workforceID', '???').substring(0, 9);
        telephoneNumber = getPrimaryAttribute(primaryAttributes, 'TelephoneNumber', '???').substring(0, 19);
        itdidmHRID = getPrimaryAttribute(primaryAttributes, 'itdidmHRID', '???').substring(0, 14);
        location = getPrimaryAttribute(primaryAttributes, 'itdprovLocation', '???').substring(0, 9).toLowerCase();
        operationalTenant = getPrimaryAttribute(primaryAttributes, 'itdprovCompany', '???').substring(0, 9).toLowerCase();
        samAccountname = (await getSamAccountName(email)).substring(0, 29).toLowerCase();
        queryParams = [dn, fullName, firstName, lastName, email, cn, workforceID, telephoneNumber, itdidmHRID, location, operationalTenant, employeeStatus];
      } catch (e) {
        console.log(`Error preparing employee '${dn}': ${e.message}`);
      }
      try {
        await db.query(queryText, queryParams);
      } catch (e) {
        console.log(`Error inserting/updating employee '${dn} (${aktMa.fullName})': ${e.message}`);
        employeeErrors++;
      }
    }
    const jMa = JSON.stringify(ma);
    try {
      fs.writeFileSync(path.resolve((typeof __dirname === 'undefined' ? folderName : __dirname), './data/idm-all-mas.json'), jMa, { flush: true });
    } catch (e) {
      console.log(`Error writing file for employees: ${e.message}`);
    }

    // #region alte Employees loeschen
    if (employeeErrors < Math.floor(ma.length * 0.1)) {
      // max 10% Fehler, daher alte Einträge löschen
      const queryText = 'DELETE FROM public.employees WHERE modified < CURRENT_TIMESTAMP - INTERVAL \'7 days\'';
      try {
        await db.query(queryText);
      } catch (e) {
        console.log(`Error deleting old employees: ${e.message}`);
      }
    }
    // #endregion
    // #endregion    
  }
  console.log(`current refreshToken=${idmConfig["refreshToken"]}`);
  await idmLogout(idmConfig["refreshToken"]);
}

async function insertMA(queryText, queryParams) {
  try {
    await db.query(queryText, queryParams);
  } catch (e) {
    console.log(`Error inserting/updating employee '${dn} (${aktMa.fullName})': ${e.message}`);
  }
}

async function dbtest() {
  //const roles=JSON.parse('./data/idm-owner-mgmt-roles.json');
  //console.log(roles[1]);


  const res = await db.query('select * from public.employees')
  console.log(res);
  //return(res);
}

//dbtest();
//main({roles:false}); // nur employees verarbeiten
main();

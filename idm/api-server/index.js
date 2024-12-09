/* Version 
24.618.1 - Erste "offizielle" Version (arbeitet noch mit den JSON-Files, die das Powershellskript erzeugt)
24.618.2 - Abfrage von Mitarbeitern
24.722.1 - GET /whoami hinzugefuegt
24.729.1 - GET /health hinzugefuegt
24.829.1 - Headerfeld ausgebessert und Begruessung um fullName erweitert
24.924.1 - Umbau auf PostgreSQL-DB als Quelle fuer Rollen und User
24.925.1 - Exports gemacht, damit man gewisse Dinge im idm-translate "mitverwenden" kann
24.1003.1 - CORS eingebaut
24.1007.1 - /idm/translate Subrouter eingebaut
24.1009.1 - isAuthenticated für alle routen (nicht nur /idm/translate - weil es den Username als Header liefert), isApiKeyPresent eingebaut
24.1105.1 - Skript ausgedünnt
24.1119.1 - routeId in die Abfrage der Rollen eingebaut
24.1119.2 - Endpoint GET /roles/:routeId hinzugefuegt
24.1121.1 - GET /roles/:routeId - umgestellt auf id (statt routeId)
24.1129.1 - queries angepasst und Reihenfolge der Route Handler geändert
*/
// sudo docker run --rm -p 8080:8080 registry.artifactory.prod.lkw-walter.com/bere/keycloak-gatekeeper:11.0.571 --client-id=idm-owner-rolemgmt --client-secret=47406b61-3f71-4f97-9934-8d3f736bb6e0 --discovery-url=https://keycloak.cross.lkw-walter.com/auth/realms/internal --cookie-access-name=kc-access --cookie-domain=localhost --listen=0.0.0.0:8080 --upstream-url=http://10.16.13.11:3001 --redirection-url=http://localhost:8080 --enable-refresh-tokens=true --encryption-key=ajsjdfjahsfjh115
/*
// Uebertragen von der Notebookfestplatte auf WIPAPL22 (auf der PAW ausführen!)
copy \\client\c$\github\pirklb\own-public-stuff\idm\api-server\index.js c:\temp /y
pscp c:\temp\index.js pirklb-sa@wipapl22:/home/pirklbr/node/idm-api
*/
const API_VERSION = '24.1129.1';
const API_KEY = 'hxzufhppo5cgw4s7e0ht';
const express = require('express');
const fs = require('node:fs');
const path = require('path');
const cors = require('cors');
const db = require('./db.js');
const axios = require('axios');
const idmTranslateRoutes = require('./routes/idm-translate.js');
const queries = {
  allEmployees: 'SELECT dn,"fullName","firstName","lastName",email,cn,"workforceID","telephoneNumber","itdidmHRID",location,"operationalTenant","employeeStatus","created","modified","samAccountname" FROM public.employees',
  allRoles: 'SELECT id,name,description,level,owners,categories,created,modified,"routeId" FROM public."ownerManagedRoles"',
  employeeByCn: 'SELECT dn,"fullName","firstName","lastName",email,cn,"workforceID","telephoneNumber","itdidmHRID",location,"operationalTenant","employeeStatus","created","modified","samAccountname" FROM public.employees WHERE cn=$1',
  roleByRoleId: 'SELECT id,name,description,level,owners,categories,created,modified,"routeId" FROM public."ownerManagedRoles" WHERE id=$1'
}

const app = express();
const port = 3001;
// app.use(bodyParser.json());
app.use('/idm/translate', idmTranslateRoutes);

// #region CORS
const corsOptions = {
  origin: function (origin, callback) {
    //    console.log(`CORS origin: ${origin}`);
    if (!origin || origin.indexOf('.') === 0 || origin.indexOf('.') < 0 || origin.toLowerCase().indexof('.lkw-walter.com') > 0) {
      callback(null, true)
    } else callback(new Error(`'${origin} - not allowed by CORS`));
  }
}
app.use(cors(corsOptions));
function isAuthenticated(req, res, next) {
  const username = req.header('X-Auth-Username');
  let fullName = '';
  if (!username) {
    throw new Error('You must be authenticated to use this functionality');
    //res.send('You must be authenticated to use this functionality');
  } else {
    req.username = username;
  }
  return next();
}
function isApiKeyPresent(req, res, next) {
  const apiKey = req.header('X-ApiKey') || 'no-key-provided';
  if (apiKey !== API_KEY) throw new Error('You must provide a valid API-KEY (X-ApiKey)');
  return next();
}
app.use(isAuthenticated);
//app.use(isApiKeyPresent);

// #endregion
let ownerManagedRoles;
let employees;
async function getRoles() {
  try {
    const { rows } = await db.query(queries.allRoles);
    for (let row of rows) {
      row.owners = row.owners.split(',').filter(e => e ? e : '') // umwandeln des owners-Strings in ein Array und filtern von "leeren" Ownern
    }
    return rows;
  } catch (error) {
    throw new Error(`IDM-API: getRoles: ${error.message}`)
  }
  //return JSON.parse(fs.readFileSync(path.resolve(__dirname,'./data/idm-owner-mgmt-roles.json')));
}

async function getEmployees() {
  function lowercaseeFirstLetter(string) {
    return string.charAt(0).toLowerCase() + string.slice(1);
  }

  try {
    const { rows } = await db.query(queries.allEmployees);
    return rows;
  } catch (error) {
    throw new Error(`IDM-API: getEmployees: ${error.message}`)
  }
}

async function init() {
  ownerManagedRoles = await getRoles();
  console.log(`init, ${ownerManagedRoles.length} owner managed roles found`);
  employees = await getEmployees();
  console.log(`init, ${employees.length} employee identities (including child identities) sucessfully loaded`);
}
init();

// #region routes 
// #region roles 
app.get('/roles/:routeId', async (req, res) => {
  console.log('/roles/:routeId', req.params.routeId);
  const roleId = decodeURIComponent(req.params.routeId);
  console.log('app.get(/roles/:routeId) - roleId:', roleId);
  const { rows } = await db.query(queries.roleByRoleId, [roleId]);
  if (rows.length > 0) {
    res.status(200).json({ status: true, role: rows[0] });
  } else {
    res.status(404).json({ status: true, role: null });
  }
});
app.get('/roles', (req, res) => {
  const qSearch = req.query.q?.toLowerCase();
  const qOwner = req.query.owner?.toLowerCase() || null;
  let erg = [];
  console.log('app.get(/roles) - username:', req.username, ', qSearch:', qSearch, 'qOwner:', qOwner, '- Start');
  //console.log(`${ownerManagedRoles.length} roles overall.`);
  if (!qSearch) {
    res.status(200).json({ status: true, roles: ownerManagedRoles.length });
  } else {
    erg = ownerManagedRoles.filter((r) => (r.name + ';' + r.description).toLowerCase().indexOf(qSearch) >= 0);
    //erg = ownerManagedRoles.filter((r) => (r.name).indexOf(qSearch) >= 0);
    //console.log(`${erg.length} roles match q (${qSearch}).`);
    if (qOwner) {
      erg = erg.filter((r) => {
        const owners = r.owners;
        if (owners.constructor === Array) {
          // "beste" Methode um festzustellen, ob owners ein Array ist
          return owners.some((o) => o.toLowerCase() === qOwner);
        } else {
          // owners ist kein Array, sondern ein string
          return owners.toLowerCase().indexOf(qOwner) > 0;
        }
      });
      //console.log(`${erg.length} roles also have correct owner (${qOwner}).`);
    }
    console.log('app.get(/roles) - qSearch:', qSearch, 'qOwner:', qOwner, '- Ende');
    if (erg) {
      res.status(200).json({ status: true, roles: erg });
    } else {
      res.status(404).json({ status: true, roles: [] });
    }
  }
})

app.post('/roles/reload', async (req, res) => {
  ownerManagedRoles = await getRoles();
  res.status(200).json({ status: true, apiversion: API_VERSION, roles: ownerManagedRoles.length, employees: employees.length });
})
// #endregion 

// #region employees 

app.get('/employees', (req, res) => {
  const qSearch = req.query.q?.toLowerCase();
  let erg = [];
  if (!qSearch) {
    res.status(200).json({ status: true, employees: employees.length });
  } else {
    erg = employees.filter((e) => (e.cN + ';' + e.fullName + ';' + e.firstName + ';' + e.lastName + ';' + e.email + ';' + e.workforceID).toLowerCase().indexOf(qSearch) >= 0);
    if (erg) {
      res.status(200).json({ status: true, employees: erg });
    } else {
      res.status(404).json({ status: true, employees: [] });
    }
  }

});
app.post('/employees/reload', async (req, res) => {
  employees = await getEmployees();
  res.status(200).json({ status: true, apiversion: API_VERSION, roles: ownerManagedRoles.length, employees: employees.length });
})
/* #endregion */

/* #region whoami */
app.get('/whoami', async (req, res) => {
  const username = (req.header('X-Auth-Username') || 'anonymous').toLowerCase();
  if (username === 'anonymous') {
    return res.status(401).json({ status: false, message: 'You must be authenticated to use this functionality' });
  }
  const data = employees.find(e => e.email.toLowerCase() === username);
  if (data) {
    data.username = username;
  } else {
    return res.status(401).json({ status: false, message: 'You must be authenticated to use this functionality' });
  }
  //console.log('/whoami: data:', data);
  return res.status(200).json({ status: true, data });
})
/* #endregion */

/* #region health */
app.get('/health', (req, res) =>
  res.status(200).json({ status: true, apiversion: API_VERSION, roles: ownerManagedRoles.length, employees: employees.length })
);
/* #endregion */

app.get('/', (req, res) =>
  res.status(200).json({ status: true, apiversion: API_VERSION, roles: ownerManagedRoles.length, employees: employees.length })
);

app.listen(port, () => {
  console.log(`IDM API listening on port ${port}`)
})

exports.employees = employees;
exports.ownerManagedRoles = ownerManagedRoles;
exports.queries = queries;
exports.db = db;

/* Version 
24.618.1 - Erste "offizielle" Version (arbeitet noch mit den JSOB-Files, die das Powershellskript erzeugt)
24.618.2 - Abfrage von Mitarbeitern
24.722.1 - GET /whoami hinzugefuegt
*/
const API_VERSION='24.618.2';
const express = require('express');
const fs = require('node:fs');
const path=require('path');

const app = express();
const port = 3001;

function getRoles() {
  return JSON.parse(fs.readFileSync(path.resolve(__dirname,'./data/idm-owner-mgmt-roles.json')));
}

function getEmployees() {
  function lowercaseeFirstLetter(string) {
    return string.charAt(0).toLowerCase() + string.slice(1);
  }
  
  function convertJsonToEmployee(j) {
    let e={}
    e.dn=j.dn;
    e.fullName=j.fullName;
    
    
    for (let p of j.primaryAttributes) { 
      if (p.attributeValues) { // manche Employees haben nicht alle Werte gesetzt
        e[lowercaseeFirstLetter(p.key)]=(p.attributeValues[0]['$']) 
      } else {
        e[lowercaseeFirstLetter(p.key)]=undefined
      }
    }
      return e
  }
  
  const json=JSON.parse(fs.readFileSync(path.resolve(__dirname,'./data/idm-all-mas.json')));
  console.log(`${json.length} employees found`);
  return json.map((j,idx) => { 
    //if (idx===0) console.log(j);
    try {
      return convertJsonToEmployee(j);
    } catch(err) {
      console.warn(`Fehler bei '${j.dn}'`);
    }
  })
}

let ownerManagedRoles=getRoles();
console.log(`${ownerManagedRoles.length} owner managed roles found`);
//console.log(ownerManagedRoles[0]);
let employees=getEmployees();
console.log(`${employees.length} employee identities (including child identities) sucessfully loaded`);
//console.log('employee[123]=',employees[123]);
//console.log('----------------------------------------------------------');


// #region routes 
// #region roles 
app.get('/roles', (req, res) => {
  const qSearch = req.query.q?.toLowerCase();
  const qOwner = req.query.owner?.toLowerCase() || null;
  let erg = [];
  //console.log(`${ownerManagedRoles.length} roles overall.`);
  if (!qSearch) {
    res.status(200).json({ status: true, roles: ownerManagedRoles.length });
  } else {
    erg = ownerManagedRoles.filter((r) => (r.name+';'+r.description).toLowerCase().indexOf(qSearch) >= 0);
    //erg = ownerManagedRoles.filter((r) => (r.name).indexOf(qSearch) >= 0);
    //console.log(`${erg.length} roles match q (${qSearch}).`);
    if (qOwner) {
      erg = erg.filter((r) => {
        const owners = r.owners;
        if (owners.constructor === Array) {
          // "beste" Methode um festzustellen, ob owners ein Array ist
          return owners.some((o) => o.toLowerCase().indexOf(qOwner)>0);
        } else {
          // owners ist kein Array, sondern ein string
          return owners.toLowerCase().indexOf(qOwner)>0;
	}
      });
      //console.log(`${erg.length} roles also have correct owner (${qOwner}).`);
    }
    if (erg) {
      res.status(200).json({ status: true, roles: erg });
    } else {
      res.status(404).json({ status: true, roles: [] });
    }
  }
})

app.post('/roles/reload',(req,res) => {
  ownerManagedRoles=getRoles();
  res.status(200).json({status:true,apiversion:API_VERSION,roles:ownerManagedRoles.length,employees:employees.length});
})
// #endregion 

// #region employees 

app.get('/employees', (req,res) => {
  const qSearch=req.query.q?.toLowerCase();
  let erg = [];
  if (!qSearch) {
    res.status(200).json({ status: true, employees: employees.length });
  } else {
    erg = employees.filter((e) => (e.cN+';'+e.fullName+';'+e.firstName+';'+e.lastName+';'+e.email+';'+e.workforceID).toLowerCase().indexOf(qSearch) >= 0);
    if (erg) {
      res.status(200).json({ status: true, employees: erg });
    } else {
      res.status(404).json({ status: true, employees: [] });
    }
  }

});
app.post('/employees/reload',(req,res) => {
  employees=getEmployees();
  res.status(200).json({status:true,apiversion:API_VERSION,roles:ownerManagedRoles.length,employees:employees.length});
})

/* #endregion */

/* #region whoami */
app.get('/whoami',(req,res) => {
  const username=req.header('x-username');
  res.send(`Hello '${username || 'anonymous'}'`);
})
/* #endregion */

app.get('/',(req,res) => 
  res.status(200).json({status:true,apiversion:API_VERSION,roles:ownerManagedRoles.length,employees:employees.length})
);
/* #endregion */


app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
})


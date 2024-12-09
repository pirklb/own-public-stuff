/* Version
24.924.1 - Initialversion
24.930.1 - Verwendung der routeId ("abgekürzte" RoleId, die in der Route transportiert wird)
24.1007.1 - GET /health eingebaut
24.1105.1 - Logging minimal geaendert
24.1122.1 - prepareIdmRest Logging eingebaut
24.1128.1 - remove IDM role member eingebaut
24.1202.1 - corrected the parameters passed from DELETE route to helperRemoveIdmRoleMember
24.1202.2 - added POST route for role assignments (helperAddRoleMember)
24.1202.3 - corrected the body for the POST request to helperAddIdmRoleMember
*/
const API_VERSION = '24.1202.3';
const express = require('express');
const idm = require('../idm');
const { employees, ownerManagedRoles, queries, db } = require("../index.js");
//const { getAuthHeader, idmConfig, idmLogin, useRefreshToken, idmLogout, invokeIdmRest, addIdmRoleMember, removeIdmRoleMember, getIdmRoleMember, initIdm } = require("../idm.js");

const bodyParser = require('body-parser');
const jsonParser = bodyParser.json();

function logger(req, res, next) {
  console.log(`${new Date()} - ${req.url} ${req.method}`);
  return next();
}

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

async function prepareIdmRest() {
  if (idm.idmConfig === undefined || Object.keys(idm.idmConfig).length === 0) {
    idm.initIdm();
  }
  if (!idm.idmConfig?.accessToken) {
    await idm.idmLogin();
  }
}

async function helperAddIdmRoleMember({ roleDN, memberDN, reason, effectiveDate = '', expiryDate = '' }) {
  await prepareIdmRest();
  const result = await idm.addIdmRoleMember({ roleDN, memberDN, reason, effectiveDate, expiryDate });
  console.log('helperAddIdmRoleMember, result:',result);
  return result;
}
async function helperRemoveIdmRoleMember({ roleDN, memberDN, reason }) {
  await prepareIdmRest();
  console.log(`helperRemoveIdmRoleMember, roleDN='${roleDN}', memberDN='${memberDN}',reason='${reason}'`);
  const result = await idm.removeIdmRoleMember({ roleDN, memberDN, reason });
  console.log('helperRemoveIdmRoleMember, result: ', result);
  return result;
}
async function helperGetIdmRoleMember({ roleDN }) {
  await prepareIdmRest();
  const result = await idm.getIdmRoleMember({ roleDN });
  console.log('helperGetIdmRoleMember, result: ', result);
  return result;
}

const router = express.Router();
router.use(jsonParser);
router.use(isAuthenticated);
//router.use(logger);

router.get('/', (req, res) => {
  //    console.log('nach Middleware ...');
  res.send(`Im /idm/translate ... (${req.username})`);
});

router.get('/roles/:routeId/assignments', async (req, res) => {
  const roleId = decodeURIComponent(req.params.routeId);
  const result = await helperGetIdmRoleMember({ roleDN: roleId })

  //console.log('r.')
  console.log(`GET /roles/assignments: ${roleId}`);
  //console.log(result);
  res.json(result);
})
  .post('/roles/:routeId/assignments', async (req, res) => {
    console.log('POST roles/routeId/assignments');
    const roleId = decodeURIComponent(req.params.routeId);
    console.log('POST roles/routeId/assignments, req.body',req.body);
    const { memberId, reason, effectiveDate = '', expiryDate = '' } = req.body;
    console.log(`POST roles/routeId/assignments,roleId='${roleId}',memberId='${memberId}',reason='${reason}'`);
    if (!memberId || !reason) {
      return res.status(400).json({status:false,result:'memberId or reason are missing in the body of the request'});
    }
    console.log(`POST /roles/assignments: ${roleId},${memberId},${reason},${effectiveDate},${expiryDate}`);
    const result = await helperAddIdmRoleMember({ roleDN:roleId, memberDN:memberId, reason, effectiveDate, expiryDate });
    res.json(result);
  })
  .delete('/roles/:routeId/assignments', async (req, res) => {
    const roleId = decodeURIComponent(req.params.routeId);
    console.log('req.body',req.body);
    const { memberId, reason } = req.body;
    if (!memberId || !reason) { 
      return res.status(400).json({status:false,result:'memberId or reason are missing in body of the request'}) 
    };
    console.log(`DELETE /roles/assignments: ${roleId},${memberId},${reason}`);
    const result = await helperRemoveIdmRoleMember({ roleDN: roleId, memberDN: memberId, reason });
    res.json(result);
  });
router.get('/health', (req, res) => {
  res.json({ status: true, apiversion: API_VERSION });
})
module.exports = router;

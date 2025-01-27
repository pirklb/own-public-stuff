// Version = 25.127.1
// Initialübernahme von idm.js (24.1129.1)

//process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const axios = require('axios');
const https = require('https');
import type { IdmConfig, InvokeIdmRestReturn } from './types';
const agent = new https.Agent({
  rejectUnauthorized: false,
});
let doDebug = false;
const STATUS_OK = 'ok';
const STATUS_ERROR = 'error';

let idmConfig: IdmConfig | {} = {};
let client; // da wird der axios Client gespeichert
const createAxiosClient = () => axios.create({
  httpsAgent: agent,
  baseURL: idmConfig['IDM_BASEURL'],
  headers: {
    'Content-Type': 'application/json; charset=utf-8',
    'Authorization': `Bearer ${idmConfig['accessToken']}`
  },
});

require('dotenv').config();

function initIdm({ debug = false } = {}): IdmConfig {
  let i: Partial<IdmConfig> = {};
  i['IDM_SERVER'] = process.env.IDM_SERVER || 'wipidm03.lkw-walter.com';
  i['IDM_BASEURL'] = `https://${idmConfig['IDM_SERVER']}/`;

  i['IDM_CLIENTID'] = process.env.IDM_CLIENTID;
  i['IDM_CLIENTSECRET'] = process.env.IDM_CLIENTSECRET && atob(process.env.IDM_CLIENTSECRET); // atob decodiert base64 Strings

  i['IDM_TOKEN_ENDPOINT'] = `https://${i.IDM_SERVER}/osp/a/idm/auth/oauth2/token`;
  i['IDM_AUTHORIZATION_ENDPOINT'] = `https://${i.IDM_SERVER}/osp/a/idm/auth/oauth2/auth`;
  i['IDM_END_SESSION_ENDPOINT'] = `https://${i.IDM_SERVER}/osp/a/idm/auth/oauth2/logout`;

  i['IDM_SERVICE_USERNAME'] = process.env.IDM_SERVICE_USERNAME;
  i['IDM_SERVICE_PASSWORD'] = process.env.IDM_SERVICE_PASSWORD && atob(process.env.IDM_SERVICE_PASSWORD); // atob decodiert base64 Strings
  doDebug = debug;
  return i as IdmConfig;
}

function getAuthHeader(clientId, clientSecret) {
  const auth = `${clientId}:${clientSecret}`;
  const b64Auth = btoa(auth);
  const authHeader = `Basic ${b64Auth}`;
  return authHeader;
}

async function idmLogin() {
  const server = idmConfig['IDM_SERVER'];
  const baseUrl = idmConfig['IDM_BASEURL'];
  const atUrl = idmConfig['IDM_TOKEN_ENDPOINT'];
  const clientId = idmConfig['IDM_CLIENTID'];
  const clientSecret = idmConfig['IDM_CLIENTSECRET'];

  const authHeader = getAuthHeader(clientId, clientSecret);
  doDebug && console.log('auth base64=', authHeader);

  try {
    const response = await axios.post(
      'https://idm.lkw-walter.com/osp/a/idm/auth/oauth2/token',
      new URLSearchParams({
        'grant_type': 'password',
        'username': idmConfig['IDM_SERVICE_USERNAME'],
        'password': idmConfig['IDM_SERVICE_PASSWORD'],
      }),
      {
        httpsAgent: agent,
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      });
    const erg = {
      accessToken: response.data.access_token,
      refreshToken: response.data.refresh_token,
    };
    idmConfig['accessToken'] = erg.accessToken;
    idmConfig['refreshToken'] = erg.refreshToken;
    doDebug && console.log('idmLogin, erg=', erg);
    return erg;
  } catch (error) {
    console.log(error);
  }
}

async function useRefreshToken(refreshToken = idmConfig['refreshToken']) {
  const teUrl = idmConfig['IDM_TOKEN_ENDPOINT'];
  const clientId = idmConfig['IDM_CLIENTID'];
  const clientSecret = idmConfig['IDM_CLIENTSECRET'];

  const authHeader = getAuthHeader(clientId, clientSecret);
  doDebug && console.log('useRefreshToken auth base64=', authHeader);

  doDebug && console.log('useRefreshToken teUrl=', teUrl);
  try {
    const response = await axios.post(
      teUrl,
      new URLSearchParams({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      }),
      {
        httpsAgent: agent,
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded'
        }
      });
    idmConfig['accessToken'] = response.data.access_token;

    doDebug && console.log('useRefreshToken, erg=', response.data.access_token);
    return response.data.access_token;
  } catch (error) {
    console.log('useRefreshToken ERROR:', error);
    return { status: STATUS_ERROR, message: error.message }
  }
}

async function idmLogout(refreshToken = idmConfig['refreshToken']) {
  const server = idmConfig['IDM_SERVER'];
  const baseUrl = idmConfig['IDM_BASEURL'];
  //  const atUrl=idmConfig['IDM_TOKEN_ENDPOINT'];
  const clientId = idmConfig['IDM_CLIENTID'];
  const clientSecret = idmConfig['IDM_CLIENTSECRET'];
  const revokeUrl = `${baseUrl}osp/a/IDM/auth/oauth2/revoke`;
  const authHeader = getAuthHeader(clientId, clientSecret);
  // curl -X POST "https://idm.lkw-walter.com/osp/a/idm/auth/oauth2/revoke" --header 'Authorization: Basic cmJwbXJlc3Q6Tm54RDF4UmU0M0RsWGtuQlk5RmE=' --header 'Content-Type: application/x-www-form-urlencoded' --data 'token_type_hint=refresh_token&token=eH8...GoU' -v
  // curl geht, axios aber nicht
  const body = (new URLSearchParams({
    'token_type_hint': 'refresh_token',
    'token': refreshToken,
  })).toString();
  try {
    const response = await axios.post(
      revokeUrl,
      body,
      {
        httpsAgent: agent,
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/x-www-form-urlencoded',
        }
      }
    );
    idmConfig['accessToken'] = '';
    idmConfig['refreshToken'] = '';
    console.log('successfully logged out from idm ...');
  } catch (error) {
    console.log('idmLogout ERROR:', error.response.status);
  };
}

async function invokeIdmRest(requestUrl: string | URL, method = 'GET', body = {}, headers = {}, allKey?: string | boolean): Promise<InvokeIdmRestReturn> {
  // die Version von Andreas Koglbauer
  // login
  //await useRefreshToken();
  if (typeof requestUrl === 'string') requestUrl = new URL(requestUrl, idmConfig['IDM_BASEURL']);
  if (!client) client = createAxiosClient();

  // normalize headers
  method = method.toUpperCase().toLowerCase();

  // build axios request
  const request = {
    method,
    url: requestUrl,
    headers,
    data: method !== 'get' ? body : undefined,
  }
  if (body) { console.log('invokeIdmRest body:', JSON.stringify(body)); }
  let response;
  let erg = {};
  try {
    response = await client.request(request);
  } catch (error) {
    if (error.response?.status === 401) {
      const accessToken = await useRefreshToken();
      // recreate client with new accessToken
      client = createAxiosClient();
      response = await client.request(request);
    } else {
      console.log('invokeIdmRest ERROR:', error);
      return { status: STATUS_ERROR, message: error.message }
    }

  }
  if (response.data) {

    // remove nextIndex and arraySize from response
    let {
      nextIndex,
      arraySize,
      ...data
    } = response.data;

    erg = data

    // if allKey is set to true, we try to get the name of the property from the response
    // if allKey is truethy (but not tru), we expect a property with the name of allKey in the response
    // this property should be an array
    // if nextIndex is set, we will try to fetch the next page
    if (allKey) {
      let allKeyPropName: string | undefined;
      if (typeof allKey === 'boolean') {
        // allKey must be true, because it is a boolean and "truthy"
        const ignoreProperties = ['total', 'hasmore']
        const remainingProperties = Object.keys(erg).filter(e => !ignoreProperties.includes(e));
        if (remainingProperties.length === 1) allKeyPropName = remainingProperties[0];
      } else allKeyPropName = allKey;

      if (!allKeyPropName) {
        return { status: STATUS_ERROR, message: 'Unable to determine allKeyPropName' }
      }
      if (!erg.hasOwnProperty(allKeyPropName)) {
        return { status: STATUS_ERROR, message: `Property '${allKeyPropName}' not found in response` }
      }

      erg = erg[allKeyPropName]

      if (!Array.isArray(erg)) {
        return { status: STATUS_ERROR, message: `Property ${allKeyPropName} is not an array` }
      }

      while (nextIndex && nextIndex > 0) {
        try {

          // um den useRefreshToken zu testen
          //await sleep(10000)

          console.log("requesting next page", nextIndex)

          const nextResponse = await client.request({
            params: { nextIndex: nextIndex },
            ...request
          });
          if (nextResponse.data) {

            let data = nextResponse.data;

            if (!data.hasOwnProperty(allKeyPropName)) {
              return { status: STATUS_ERROR, message: `Property ${allKeyPropName} not found in response` }
            }

            if (!Array.isArray(data[allKeyPropName])) {
              return { status: STATUS_ERROR, message: `Property ${allKeyPropName} is not an array` }
            }

            erg = (erg as Array<any>).push(...data[allKeyPropName]);

            nextIndex = data.nextIndex

          }
        } catch (error) {

          if (error.response?.status === 401) {
            const accessToken = await useRefreshToken();
            // recreate client with new accessToken
            client = axios.create({
              httpsAgent: agent,
              baseURL: idmConfig['IDM_BASEURL'],
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Authorization': `Bearer ${idmConfig['accessToken']}`
              },
            });

          } else {
            console.log('invokeIdmRest ERROR:', error);
            return { status: STATUS_ERROR, message: error.message }
          }
        }


      }

    }

  }

  //console.debug(response);

  return { status: STATUS_OK, data: erg }
}

async function addIdmRoleMember({ roleDN, memberDN, reason, effectiveDate = '', expiryDate = '' }) {
  const body = {
    reason,
    assignments: [
      {
        id: roleDN,
        assignmentToList: [
          {
            assignedToDn: memberDN,
            subtype: "user",
          }
        ],
        effectiveDate,
        expiryDate,
      }]
  }

  let response = await invokeIdmRest('/IDMProv/rest/catalog/roles/role/assignments/assign', 'POST', body, {});
  if (!response?.status) return { status: STATUS_OK, result: response }; else return response;
}

async function removeIdmRoleMember({ roleDN, memberDN, reason }) {
  const body = {
    reason,
    assignments: [
      {
        id: roleDN,
        entityType: 'role',
        assignmentToList: [
          {
            assignedToDn: memberDN,
            subtype: "user",
          }
        ],
      }]
  }

  let response = await invokeIdmRest('/IDMProv/rest/access/assignments/list', 'DELETE', body, {});
  if (!response?.status) return { status: STATUS_OK, result: response }; else return response;
}

async function getIdmRoleMember({ roleDN }) {
  const body = {
    dn: roleDN,
  }
  let response = await invokeIdmRest("/IDMProv/rest/catalog/roles/role/assignments/v2?size=1000", "POST", body, {}, "assignmentStatusList");
  if (!response?.status) return { status: STATUS_OK, result: response }; else return response;
  //let response = await invokeIdmRest('IDMProv/rest/catalog/roles/role/assignments/v2?sortBy=name','GET',{},{})
}

async function main() {
  idmConfig = initIdm({ debug: true });

  doDebug && console.log('service user=', idmConfig['IDM_SERVICE_USERNAME']);
  doDebug && console.log('service password=', idmConfig['IDM_SERVICE_PASSWORD']);

  doDebug && console.log('IDM_SERVER=', idmConfig['IDM_SERVER']);
  doDebug && console.log('IDM_TOKEN_ENDPOINT=', idmConfig['IDM_TOKEN_ENDPOINT']);
  doDebug && console.log(`IDM_CLIENTSECRET='${idmConfig['IDM_CLIENTSECRET'] || 'unbekannt'}'`);

  console.log('      login to idm ...');
  const tokens = await idmLogin();
  console.log('tokens from idmLogin():', tokens);
  //idmConfig['refreshToken']=tokens.refreshToken;
  //idmConfig['accessToken']=tokens.accessToken;

  //Example without using nextIndex
  //  let response = await invokeIdmRest('/IDMProv/rest/catalog/users', 'GET', {}, {});
  //  console.log(response)

  // request all users through nextIndex
  //  response = await invokeIdmRest('/IDMProv/rest/catalog/users', 'GET', {}, {}, 'users');
  //  console.log(response)

  // Test Assign Role - pirklb to ext_fca_slovakia:
  let memberDN = 'cn=p_19849475,ou=pers,ou=users,o=idvault'
  let roleDN = 'cn=it_ads_group_ext_fca_slovakia,cn=level10,cn=roledefs,cn=roleconfig,cn=appconfig,cn=userapplication,cn=driverset,o=system'
  let reason = 'Test (RP)'

  //response = await addIdmRoleMember(roleDN,memberDN,reason);
  //console.log(response) ;

  //  response = await removeIdmRoleMember(roleDN,memberDN,reason);
  //  console.log(response) ;
  let response = await getIdmRoleMember({ roleDN });
  console.log(response);

  //  console.dir(idmConfig);
  console.log('      ... and now ... logout again ... ');
  await idmLogout();
  console.dir(idmConfig);
}

//main();

exports.idmConfig = idmConfig;
exports.getAuthHeader = getAuthHeader;
exports.idmLogin = idmLogin;
exports.useRefreshToken = useRefreshToken;
exports.idmLogout = idmLogout;
exports.invokeIdmRest = invokeIdmRest;
exports.addIdmRoleMember = addIdmRoleMember;
exports.removeIdmRoleMember = removeIdmRoleMember;
exports.getIdmRoleMember = getIdmRoleMember;
exports.initIdm = initIdm;
exports.client = client;
exports.STATUS_OK = STATUS_OK;

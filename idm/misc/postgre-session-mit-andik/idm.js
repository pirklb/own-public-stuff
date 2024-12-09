// Version = 24.729.2
// 24.704.1 - invokeIdmRest - von Andi Kogelbauer
// 24.704.2 - mergen mit der letzten Version am wipapl22
// 24.704.3 - Helperfunktionen addIdmRoleMember und removeIdmRoleMember hinzugefuegt
// 24.704.4 - getIdmRoleMember hinzugefuegt
// 24.709.1 - Erweiterung um invokeIdmRest von chatGPT
// 24.728,1 - Rückbau auf invokeIdmRest - von Andi Kogelbauer
// 24.729.2 - idmConfig als export aufgenommen und Funktion initIdm
// 24.730.1 - exports auf "require" umgestellt

//process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const axios = require('axios');
const https = require('https');
const agent = new https.Agent({
  rejectUnauthorized: false,
});
const doDebug = false;
const idmConfig = {};

require('dotenv').config();

function initIdm() {
  idmConfig['IDM_SERVER'] = process.env.IDM_SERVER || 'wipidm03.lkw-walter.com',
  idmConfig['IDM_BASEURL'] = `https://${idmConfig['IDM_SERVER']}/`;

  idmConfig['IDM_CLIENTID'] = process.env.IDM_CLIENTID,
  idmConfig['IDM_CLIENTSECRET'] = atob(process.env.IDM_CLIENTSECRET), // atob decodiert base64 Strings

  idmConfig['IDM_TOKEN_ENDPOINT'] = `https://${idmConfig.IDM_SERVER}/osp/a/idm/auth/oauth2/token`;
  idmConfig['IDM_AUTHORIZATION_ENDPOINT'] = `https://${idmConfig.IDM_SERVER}/osp/a/idm/auth/oauth2/auth`;
  idmConfig['IDM_END_SESSION_ENDPOINT'] = `https://${idmConfig.IDM_SERVER}/osp/a/idm/auth/oauth2/logout`;

  idmConfig['IDM_SERVICE_USERNAME'] = process.env.IDM_SERVICE_USERNAME;
  idmConfig['IDM_SERVICE_PASSWORD'] = atob(process.env.IDM_SERVICE_PASSWORD); // atob decodiert base64 Strings

  return idmConfig;
}

function getAuthHeader(clientId,clientSecret) {
  const auth=`${clientId}:${clientSecret}`;
  const b64Auth = btoa(auth);
  const authHeader = `Basic ${b64Auth}`;
  return authHeader;
}

async function idmLogin() {
  const server=idmConfig['IDM_SERVER'];
  const baseUrl=idmConfig['IDM_BASEURL'];
  const atUrl=idmConfig['IDM_TOKEN_ENDPOINT'];
  const clientId=idmConfig['IDM_CLIENTID'];
  const clientSecret=idmConfig['IDM_CLIENTSECRET'];

  const authHeader = getAuthHeader(clientId,clientSecret);
  doDebug && console.log('auth base64=',authHeader);

  //curl -X POST "https://idm.lkw-walter.com/osp/a/idm/auth/oauth2/token" --header 'Authorization: Basic cmJwbXJlc3Q6Tm54RDF4UmU0M0RsWGtuQlk5RmE=' --header 'Content-Type: application/x-www-form-urlencoded' --data 'grant_type=password&username=psu-it-role-parent-mgmt&password=%40fr7R%234Q4nZN!0KEbK1k' -v
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
      accessToken:response.data.access_token,
      refreshToken: response.data.refresh_token,
    };
    idmConfig['accessToken']=erg.accessToken;
    idmConfig['refreshToken']=erg.refreshToken;
    doDebug && console.log('idmLogin, erg=',erg);
    return erg;
  } catch(error) {
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
        return {status: 'error', message: error.message}
    }
}

async function idmLogout(refreshToken) {
  const server=idmConfig['IDM_SERVER'];
  const baseUrl=idmConfig['IDM_BASEURL'];
//  const atUrl=idmConfig['IDM_TOKEN_ENDPOINT'];
  const clientId=idmConfig['IDM_CLIENTID'];
  const clientSecret=idmConfig['IDM_CLIENTSECRET'];
  refreshToken=refreshToken || idmConfig['refreshToken'];
  const revokeUrl = `${baseUrl}osp/a/IDM/auth/oauth2/revoke`;
  const authHeader = getAuthHeader(clientId,clientSecret);
// curl -X POST "https://idm.lkw-walter.com/osp/a/idm/auth/oauth2/revoke" --header 'Authorization: Basic cmJwbXJlc3Q6Tm54RDF4UmU0M0RsWGtuQlk5RmE=' --header 'Content-Type: application/x-www-form-urlencoded' --data 'token_type_hint=refresh_token&token=eH8...GoU' -v
// curl geht, axios aber nicht
  const body = (new URLSearchParams({
      'token_type_hint': 'refresh_token',
      'token': refreshToken,
    })).toString();
  console.log(`URL='${revokeUrl}'`);
  console.log(`body='${body}'`);
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
  } catch (error) {
    console.log('idmLogout ERROR:',error.response.status);
  };
}

async function invokeIdmRest(requestUrl, method = 'GET', body = {}, headers = {}, allKey) {
// die Version von Andreas Koglbauer
    // login
    await useRefreshToken();

    let client = axios.create({
        httpsAgent: agent,
        baseURL: idmConfig['IDM_BASEURL'],
        headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': `Bearer ${idmConfig['accessToken']}`
        },
    });

    // normalize headers
    method = method.toUpperCase().toLowerCase();

    // build axios request
    const request = {
        method,
        url: requestUrl,
        headers,
        data: method !== 'get' ? body : undefined,
    }

    let response;
    let erg = {};
    try {
        response = await client.request(request);
        if (response.data) {

            // remove nextIndex and arraySize from response
            let {
                nextIndex,
                arraySize,
                ...data
            } = response.data;

            erg = data

            // if allKey is set, we expect an property with the name of allKey in the response
            // this property should be an array
            // if nextIndex is set, we will try to fetch the next page
            if (allKey) {

                if (!erg.hasOwnProperty(allKey)) {
                    return {status: 'error', message: `Property ${allKey} not found in response`}
                }

                erg = erg[allKey]

                if (!Array.isArray(erg)) {
                    return {status: 'error', message: `Property ${allKey} is not an array`}
                }

                while (nextIndex && nextIndex > 0) {
                    try {

                        // um den useRefreshToken zu testen
                        //await sleep(10000)

                        console.log("requesting next page", nextIndex)

                        const nextResponse = await client.request({
                            params: {nextIndex: nextIndex},
                            ...request
                        });
                        if (nextResponse.data) {

                            let data = nextResponse.data;

                            if (!data.hasOwnProperty(allKey)) {
                                return {status: 'error', message: `Property ${allKey} not found in response`}
                            }

                            if (!Array.isArray(data[allKey])) {
                                return {status: 'error', message: `Property ${allKey} is not an array`}
                            }

                            erg = erg.concat(data[allKey]);

                            nextIndex = data.nextIndex

                        }
                    }   catch (error) {

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
                            return {status: 'error', message: error.message}
                        }
                    }


                }

            }

        }

        //console.debug(response);
    } catch (error) {

        //error.response.status

        console.log('invokeIdmRest ERROR:', error);
        return {status: 'error', message: error.message}
    }

    return erg
}
  // von chatGPT aus Powershell übersetzt ...
async function invokeIdmRestChatGPT({
  requestUrl,
  method = 'GET',
  body = null,
  headers = {},
  all = false
}) {
  // Funktion um Basis URL zu bekommen
async function getIdmInfo(info) {
    // Implementiere die Funktion hier
    // Beispiel:
    return 'https://base.url'; // Ersetze dies mit der tatsächlichen Implementierung
  }

  // Funktion um Access Token zu erneuern
async function useRefreshToken() {
    // Implementiere die Funktion hier
    // Beispiel:
    return 'new_access_token'; // Ersetze dies mit der tatsächlichen Implementierung
  }

  if (!/^https?:\/\//.test(requestUrl)) {
    const baseUrl = await getIdmInfo('BaseUrl');
    requestUrl = baseUrl + requestUrl;
  }

  if (!headers['Content-Type']) {
    headers['Content-Type'] = 'application/json; charset=utf-8';
  }

  let accToken = await useRefreshToken(); // Hole das Access Token
  headers.Authorization = `Bearer ${accToken}`;

  let response;
  try {
    const res = await axios({
      url: requestUrl,
      method: method,
      headers: headers,
      data: body
    });
    response = res.data;
  } catch (error) {
    const statusCode = error.response ? error.response.status : null;
    const statusMessage = error.response ? error.response.statusText : null;
    console.error(`Unerwartete Exception '${statusCode}:${statusMessage}'`);
    return null;
  }

  if (response) {
    let propname;
    const keys = Object.keys(response);
    if (keys.length === 1) {
      propname = keys[0];
    } else {
      propname = keys.find(key => Array.isArray(response[key]));
    }

    let result = response[propname];

    if (all) {
      while (response.nextIndex && response.nextIndex > 0) {
        try {
          const res = await axios({
            url: `${requestUrl}&nextIndex=${response.nextIndex}`,
            method: method,
            headers: headers,
            data: body
          });
          response = res.data;
          result = result.concat(response[propname]);
        } catch (error) {
          const statusCode = error.response ? error.response.status : null;
          if (statusCode === 401) {
            console.log("401 - AccessToken erneuern");
            accToken = await useRefreshToken();
            headers.Authorization = `Bearer ${accToken}`;
          }
        }
      }
    }
    return result;
  } else {
    return null;
  }
}

async function addIdmRoleMember(roleDN,memberDN,reason) {
  const body={
    reason,
    assignments:[
      {
        id:roleDN,
        assignmentToList:[
          {assignedToDn:memberDN,
          subtype:"user",}
        ],
        effectiveDate:'',
        expiryDate:'',
  }]
  }

  let response = await invokeIdmRest('/IDMProv/rest/catalog/roles/role/assignments/assign', 'POST', body, {});
  return response;
}

async function removeIdmRoleMember(roleDN,memberDN,reason) {
  const body={
    reason,
    assignments:[
      {
        id:roleDN,
        entityType:'role',
        assignmentToList:[
          {assignedToDn:memberDN,
          subtype:"user",}
        ],
  }]
  }

  let response = await invokeIdmRest('/IDMProv/rest/access/assignments/list', 'DELETE', body, {});
  return response;
}

async function getIdmRoleMember(roleDN) {
  const body={
    dn:roleDN,
  }
  let response = await invokeIdmRest("/IDMProv/rest/catalog/roles/role/assignments/v2","POST",body,{},"assignmentStatusList");
  return response;
  //let response = await invokeIdmRest('IDMProv/rest/catalog/roles/role/assignments/v2?sortBy=name','GET',{},{})
}

async function main() {
  idmConfig = {}

  idmConfig['IDM_SERVER'] = process.env.IDM_SERVER || 'wipidm03.lkw-walter.com',
  idmConfig['IDM_BASEURL'] = `https://${idmConfig['IDM_SERVER']}/`;

  idmConfig['IDM_CLIENTID'] = process.env.IDM_CLIENTID,
  idmConfig['IDM_CLIENTSECRET'] = atob(process.env.IDM_CLIENTSECRET), // atob decodiert base64 Strings

  idmConfig['IDM_TOKEN_ENDPOINT'] = `https://${idmConfig.IDM_SERVER}/osp/a/idm/auth/oauth2/token`;
  idmConfig['IDM_AUTHORIZATION_ENDPOINT'] = `https://${idmConfig.IDM_SERVER}/osp/a/idm/auth/oauth2/auth`;
  idmConfig['IDM_END_SESSION_ENDPOINT'] = `https://${idmConfig.IDM_SERVER}/osp/a/idm/auth/oauth2/logout`;

  idmConfig['IDM_SERVICE_USERNAME'] = process.env.IDM_SERVICE_USERNAME;
  idmConfig['IDM_SERVICE_PASSWORD'] = atob(process.env.IDM_SERVICE_PASSWORD); // atob decodiert base64 Strings

  doDebug && console.log('service user=',idmConfig['IDM_SERVICE_USERNAME']);
  doDebug && console.log('service password=',idmConfig['IDM_SERVICE_PASSWORD']);

  doDebug && console.log('IDM_SERVER=',idmConfig['IDM_SERVER']);
  doDebug && console.log('IDM_TOKEN_ENDPOINT=',idmConfig['IDM_TOKEN_ENDPOINT']);
  doDebug && console.log(`IDM_CLIENTSECRET='${idmConfig.IDM_CLIENTSECRET}'`);

  console.log('      login to idm ...');
  const tokens=await idmLogin();
  console.log('tokens from idmLogin():',tokens);
  //idmConfig['refreshToken']=tokens.refreshToken;
  //idmConfig['accessToken']=tokens.accessToken;

    //Example without using nextIndex
//  let response = await invokeIdmRest('/IDMProv/rest/catalog/users', 'GET', {}, {});
//  console.log(response)

  // request all users through nextIndex
//  response = await invokeIdmRest('/IDMProv/rest/catalog/users', 'GET', {}, {}, 'users');
//  console.log(response)

    // Test Assign Role - pirklb to ext_fca_slovakia:
  memberDN='cn=p_19849475,ou=pers,ou=users,o=idvault'
  roleDN='cn=it_ads_group_ext_fca_slovakia,cn=level10,cn=roledefs,cn=roleconfig,cn=appconfig,cn=userapplication,cn=driverset,o=system'
  reason='Test (RP)'

  //response = await addIdmRoleMember(roleDN,memberDN,reason);
  //console.log(response) ;

//  response = await removeIdmRoleMember(roleDN,memberDN,reason);
//  console.log(response) ;
response = await getIdmRoleMember(roleDN);
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
exports.getIdmRoleMember = getIdmRoleMember;
exports.initIdm = initIdm;

// get Member (IDM id e_... or p_...) of member of roles and export them as JSON-file (Array)
const fs=require('node:fs')
const idm=require('./idm.js');
idm.initIdm();
await idm.idmLogin();

// information about the roles which should be queried and the resulting filename
let roles2=[
{fn:'SW_ATL_Jira_ext.json',cn:'cn=IT_ADS_Group_SW_ATL_Jira_ext,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UserApplication,cn=DriverSet,o=System'},
{fn:'SW_ATL_Confluence_ext.json',cn:'cn=IT_ADS_Group_SW_ATL_Confluence_ext,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UserApplication,cn=DriverSet,o=System'},
{fn:'SW_ATL_Confluence_int.json',cn:'cn=IT_ADS_Group_SW_ATL_Confluence_int,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UserApplication,cn=DriverSet,o=System'},
{fn:'SW_ATL_BitBucket_ext.json',cn:'cn=IT_ADS_Group_SW_ATL_BitBucket_ext,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UserApplication,cn=DriverSet,o=System'},
{fn:'SW_ATL_BitBucket_int.json',cn:'cn=IT_ADS_Group_SW_ATL_BitBucket_int,cn=Level10,cn=RoleDefs,cn=RoleConfig,cn=AppConfig,cn=UserApplication,cn=DriverSet,o=System'},
];

async function main() {
  for (const { cn, fn } of roles2) {
    try {
      let erg = await idm.getIdmRoleMember({ roleDN: cn });
      let j2 = JSON.stringify(erg.result.map(e => e.recipientDn.replace('cn=','').replace(/,.*$/,'')));
      fs.writeFileSync(`/tmp/${fn}`, j2);
    } catch (error) {
      console.error(`Fehler bei Rolle ${cn}:`, error);
    }
  }
}

main();

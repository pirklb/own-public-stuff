export type IdmConfig = {
    IDM_SERVER: string,
    IDM_BASEURL: string,
    IDM_CLIENTID?: string,
    IDM_CLIENTSECRET?: string,
    IDM_TOKEN_ENDPOINT: string,
    IDM_AUTHORIZATION_ENDPOINT: string,
    IDM_END_SESSION_ENDPOINT: string,
    IDM_SERVICE_USERNAME?: string,
    IDM_SERVICE_PASSWORD?: string,
    accessToken?: string,
    refreshToken?: string,
};

export type InvokeIdmRestReturn = {
    status: string;
    statusCode?: number;
    data?: any;
    message?: string;
}
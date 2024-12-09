# IDM API-Server

Der IDM API-Server arbeitet einerseits mit den Daten aus der PostgreSQL-Datenbank (auf der IP 10.16.38.203) und andererseits direkt mit dem IDM-System.

## Routen - aus index.js

### GET /roles

**Route Parameter**: Keine
**Query Parameter**:
- `q` ... query (Name oder Description der Rolle müssen diesen String enthalten) - wenn kein q angegeben ist, wird nur die Anzahl der Ownermanaged Rollen zurückgegeben
- `owner` ... ID des Owners im IDM (p_*MARefNr*)
**Ergebnis**:
Ein Array mit den "passenden" Rollen.

### POST /roles/reload

**Route Parameter**: Keine
**Query Parameter**: Keine
**Ergebnis**:
Ein Objekt mit Statusinformationen  (nachdem die Rollen-Daten aus der PostgreSQL-Datenbank neu ausgelesen wurden)::
- status: true
- apiversion: Die API-Version
- roles: Anzahl der ownermanaged Rollen
- employees: Anzahl der employees (ACHTUNG: Child-Identities der Mitarbeiter zählen als eigenständige employees)

### GET /employees

**Route Parameter**: Keine
**Query Parameter**: 
- `q` ... query (wird in der Id, dem Vornamen, den Nachnamen, dem vollen Namen, der primären E-Mailadresse und der Personalnummer gesucht)

### POST /employees/reload

**Route Parameter**: Keine
**Query Parameter**: Keine
**Ergebnis**:
Ein Objekt mit Statusinformationen (nachdem die Employee-Daten aus der PostgreSQL-Datenbank neu ausgelesen wurden):
- status: true
- apiversion: Die API-Version
- roles: Anzahl der ownermanaged Rollen
- employees: Anzahl der employees (ACHTUNG: Child-Identities der Mitarbeiter zählen als eigenständige employees)

### GET /health

**Route Parameter**: Keine
**Query Parameter**: Keine
**Ergebnis**:
Ein Objekt mit Statusinformationen - dient aber in Wahrheit dazu zu prüfen, ob die API "funktioniert" (irgendwas mit Statuscode 200 zurückliefert)
- status: true
- apiversion: Die API-Version
- roles: Anzahl der ownermanaged Rollen
- employees: Anzahl der employees (ACHTUNG: Child-Identities der Mitarbeiter zählen als eigenständige employees)

## Routen - aus routes/idm-translate.js

### GET /idm/translate/

**Route Parameter**: Keine
**Query Parameter**: Keine
**Ergebnis**:
Das ist eine Test-Route, sie gibt "Im /idm/translate ...(mailadresse)" (des angemeldeten Benutzers retour)

### GET /idm/translate/roles/:routeId/assignments

Liefert die Rollezuweisungen für eine bestimmte Rolle.

**Route Parameter**: routeId (das ist die encodeURLComponent distinguishedNames der Rolle) 
**Query Parameter**: keine
**Ergebnis**:
{ status: true, result: Array mit den Mitgliedern }
### POST /idm/translate/roles/:routeId/assignments

Fügt eine neue Rollenzuweisung für eine Bestimmte Rolle hinzu.

**Route Parameter**: routeId (das ist eine "verkürzte" Version des distinguishedNames der Rolle - in der PostgreSQL Datenbank im Feld routeId gespeichert). Diese routeId ist IDM selbst unbekannt
**Query Parameter**: keine
**Request Body**: 
- `memberId`: Der cn des hinzuzufügenden Mitglieds
- `reason`: Die Begründung für die Rollenzuweisung
- `effectiveDate` (Standardwert: ''): Der Beginnzeitpunkt für die Rollenzuweisung - Format nachtragen
- `expiryDate` (Standardwert: ''): Der Endzeitpunkt für die Rollenzuweisung - Format nachtragen

### DELETE /idm/translate/roles/:routeId/assignments

Entfernt eine Rollenzuweisung für einen bestimmten Assignee.

**Route Parameter**: routeId (das ist eine "verkürzte" Version des distinguishedNames der Rolle - in der PostgreSQL Datenbank im Feld routeId gespeichert). Diese routeId ist IDM selbst unbekannt
**Query Parameter**: keine
**Request Body**: 
- `memberId`: Der cn des hinzuzufügenden Mitglieds
- `reason`: Die Begründung für die Rollenzuweisung


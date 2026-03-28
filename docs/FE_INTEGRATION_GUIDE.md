# Frontend (FE) Integration Guide - CRM Backend

This guide is designed for your Frontend partner (and their AI assistant) to rapidly build a high-performance **Angular 18** application that integrates seamlessly with this CRM Backend.

## 1. STRATEGIC CONTEXT
- **Architecture**: "Thin Nest, Thick PostgreSQL". All business logic and validations are handled by the backend SQL dispatchers.
- **Auth Strategy**: **Cookie-based sessions** (HttpOnly). 
    - **Crucial**: The Angular app MUST set `withCredentials: true` in all HttpClient requests.
    - **No JWT**: Do not look for Bearer tokens; the browser handles the session cookie automatically.

## 2. CORE INTEGRATION ASSETS
Share the following assets with your FE partner:

### A. Swagger/OpenAPI Documentation
- **Live UI**: [http://localhost:3000/api/docs](http://localhost:3000/api/docs)
- **Portable Contract**: [docs/openapi.json](file:///c:/Projects/crm-lead-management-backend/docs/openapi.json)

> [!TIP]
> **Sharing without Deployment**: You can share the [openapi.json](file:///c:/Projects/crm-lead-management-backend/docs/openapi.json) file directly with your partner. They can import this JSON into tools like **Postman**, **Insomnia**, or **Swagger Editor** to see the full documentation offline. 
> 
> Most importantly, they can use it with **OpenAPI Generator** to automatically build all Angular services and models without writing a single line of boilerplate.

### B. The Response Envelope
Every API response follows this exact structure:
```json
{
  "rid": "s-lead-created",
  "statusCode": 201,
  "data": { ... },
  "message": "Operation successful",
  "meta": { "timestamp": "2026-03-28T..." }
}
```

## 3. ANGULAR 18 IMPLEMENTATION TIPS
1.  **Cookie Interceptor**: Create a global interceptor to enforce credentials.
    ```typescript
    export const authInterceptor: HttpInterceptorFn = (req, next) => {
      const authReq = req.clone({ withCredentials: true });
      return next(authReq);
    };
    ```
2.  **Signals for State**: Use Angular 18 Signals to manage the `User Profile` and `Permissions` globally.
3.  **Dynamic UI (RBAC)**: Upon login, call `/api/auth/profile`. Use the returned `permissions[]` (slugs like `leads:create`) to show/hide UI elements using an `NgIf` or a custom structural directive.

## 4. MASTER PROMPT FOR FE AI PARTNER
Copy and paste this prompt when starting the Frontend project:

> "We are building a CRM Frontend in **Angular 18** using **Signals** and **TailwindCSS**. The backend is a NestJS project using **Cookie-based sessions** (HttpOnly). 
> 
> Here is our API Contract:
> 1. Base URL: `http://localhost:3000/api`
> 2. All requests must include `withCredentials: true`.
> 3. Every response is wrapped in a `{ rid, statusCode, data, message }` envelope.
> 
> Please generate the **Auth Service** and **Leads Management Component** first. Use the provided API endpoint table for route details and DTO structures."

---

## 5. API ENDPOINT SUMMARY (Snapshot)

| Module | Route | Method | Description |
| :--- | :--- | :--- | :--- |
| **Auth** | `/auth/login` | `POST` | Sets `crm_session` cookie. |
| **Leads**| `/leads` | `POST` | Create a new lead. |
| **Leads**| `/leads/:id/status` | `PATCH` | Update status (negotiating, won, etc). |
| **Leads**| `/leads/:id/convert`| `POST` | Convert lead to Project (Requires linked Contact). |
| **Tasks**| `/tasks` | `POST` | Create task for a Project. |
| **Search**| `/search?q=...` | `GET` | Global unified search across Leads/Projects/Tasks. |
| **RBAC**  | `/rbac/roles` | `GET` | (Admin Only) View and configure role permissions. |

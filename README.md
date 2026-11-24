# Linkup

**Connect. Share. Discover.**

Linkup is a lightweight, responsive social networking website starter. It uses HTML, CSS, JavaScript modules and Supabase.

## What's included

- Email/password sign-up and login
- User profile creation and editing
- Text posts and optional externally hosted image URLs
- Chronological latest-first feed
- Likes and comments
- Follow relationships
- People search and discovery
- Notifications list (notification generation is not automated yet)
- Post reporting
- Starter community rules and privacy/terms pages
- Responsive desktop and mobile layouts

## Important project separation

This project is independent of the Arabic Learning Dictionary. Create a **new Supabase project** for Linkup. Do not use credentials from another project.

## 1. Create a Supabase project

1. Visit https://supabase.com and create a new project named `Linkup`.
2. Open **SQL Editor**.
3. Copy and run `sql/schema.sql`.
4. Open **Project Settings → API** (or API Keys).
5. Copy the Project URL and the anon/publishable key.

Never use a `service_role` or secret key in browser code.

## 2. Configure the website

1. In the `js` folder, duplicate `config.example.js`.
2. Name the duplicate `config.js`.
3. Add your new Linkup Supabase URL and anon/publishable key.
4. Save the file.

Example:

```js
export const SUPABASE_URL = "https://your-project-ref.supabase.co";
export const SUPABASE_ANON_KEY = "your-anon-or-publishable-key";
```

`config.js` is ignored by `.gitignore`. Keep your credentials out of public commits.

## 3. Run locally

Because the app uses JavaScript modules, open it through a local web server, not by double-clicking `index.html`.

For example, if Python is installed:

```bash
python -m http.server 8000
```

Then open `http://localhost:8000`.

You can also use a code editor's local preview/server feature.

## 4. Deploy

You can publish the static files through GitHub Pages or Cloudflare Pages. Upload the project files and configure the site root to the repository root. Add the production site URL to Supabase **Authentication → URL Configuration** under Site URL and Redirect URLs.

For a public production launch, use HTTPS.

## Current limitations — read before testing

This is a functional starter, not a production-ready public social network.

- Profile and post visibility currently uses a basic signed-in-member model. Private-account follow approval and complete block filtering are not implemented yet.
- The Explore and feed queries are starter queries and need additional privacy/block filtering before public release.
- The photo field currently accepts an image URL. A secure image upload flow using Supabase Storage, file-size limits and content checks should be added before launch.
- Notifications can be listed and marked read, but like/comment/follow notification generation is not automated yet.
- Reporting stores reports for review. There is no admin moderation dashboard or alerting workflow yet.
- Users can create and manage their own posts, but account deletion/export workflows need to be added.
- Email verification and password reset should be configured and tested.
- Supabase free-tier projects can pause due to inactivity and have storage/usage limits.

Keep the site in private testing until privacy controls, moderation, account deletion, security, accessibility and legal pages are reviewed and tested. Do not collect sensitive personal information. Establish an appropriate age policy and safeguarding process before inviting the general public.

## Database tables

`profiles`, `posts`, `likes`, `comments`, `follows`, `notifications`, `reports`, `blocks`.

See `sql/schema.sql` for tables, indexes, signup trigger and Row Level Security policies.

## License

No open-source license is granted by this starter unless a separate LICENSE file is added.

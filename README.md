# Doctor Appointment System

PHP 8 + MySQL 8 academic project. Timezone: Asia/Karachi. Appointments use 30-minute slots.

## Architecture overview

This project uses a simple server-rendered three-layer architecture with separate folders:

```text
Browser
  |
  v
frontend/                    Presentation and web layer
  index.php                  Routes pages, handles forms, renders HTML
  assets/style.css           Shared responsive styling
  |
  v
backend/                     Application and server-side layer
  config.php                 Session, timezone, and PDO database bootstrap
  includes/functions.php     Authentication, authorization, CSRF, escaping,
                             flash messages, and appointment-slot generation
  create_admin.php            CLI-only administrator setup utility
  |
  v
Data layer
  database/schema.sql        MySQL 8 database, tables, constraints, indexes
  users                      Accounts and roles
  doctors                    Doctor profiles
  doctor_schedules           Weekly availability
  appointment_slots          Generated 30-minute slots
  appointments               Booking and appointment history
```

### Folder structure for the presentation

- **Frontend:** `frontend/index.php` contains the server-rendered pages and forms; `frontend/assets/` contains the CSS presentation layer.
- **Backend:** `backend/config.php` initializes the app; `backend/includes/` contains reusable business and security helpers; `backend/create_admin.php` is a CLI setup tool. The root `index.php` is a small public entry-point bridge.
- **Database:** `database/schema.sql` creates the MySQL schema. Foreign keys connect users, doctors, schedules, slots, and appointments. A generated column plus unique index prevents two active bookings for the same slot.

### Request and booking flow

1. The browser requests the root `index.php?page=...`.
2. The root entry point loads `frontend/index.php`.
3. `backend/config.php` starts the session and opens the PDO connection.
4. `frontend/index.php` refreshes the current user, validates the requested route, and enforces role permissions.
5. Forms include a CSRF token. Booking locks the selected slot in a transaction, inserts the appointment, and marks the slot as booked.
6. The response redirects back to a page and displays a session flash message.

### Suggested Loom walkthrough

1. Show this README architecture diagram and the folder tree.
2. Open `database/schema.sql` and explain the five main tables and booking constraint.
3. Open `backend/config.php` and `backend/includes/functions.php` to show the PDO, session, CSRF, and role helpers.
4. Open `frontend/index.php` and explain the route/action flow.
5. Demonstrate the user journey: admin creates a doctor, doctor sets availability, patient books a slot, and the appointment appears in the relevant dashboards.

### Git history for submission

Use small, meaningful commits so the project story is easy to explain:

```text
1. Document doctor appointment system architecture
   Baseline project plus architecture and file responsibility documentation.
2. Add submission walkthrough guidance
   Loom walkthrough and Git history notes for the final presentation.
```

For future work, commit one concern at a time, for example `Fix appointment cancellation validation` or `Improve responsive appointment layout`. Avoid committing passwords or real patient data.

### Validation

From WSL, run `php -l` against each PHP file before recording the demo. The current project passes syntax checks for `frontend/index.php`, `backend/config.php`, `backend/create_admin.php`, and `backend/includes/functions.php`.

## Features
- Patient signup/login, doctor directory, booking, appointment history and eligible cancellation.
- Doctor login, weekly schedule editor, own appointment list, cancellation and completion.
- Admin login, doctor account creation/deactivation, and system-wide appointment view.
- PDO prepared statements, password hashing, sessions, CSRF tokens, ownership checks, transactional booking, and a database uniqueness rule preventing duplicate active bookings.

## 1. Create a database user
Run in Ubuntu/WSL:

```bash
sudo mysql
```

Then at the `mysql>` prompt (use a strong password and use the same password in `config.php`):

```sql
CREATE USER IF NOT EXISTS 'das_app'@'localhost' IDENTIFIED BY 'ChangeThisPassword123!';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX ON doctor_appointment_system.* TO 'das_app'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

The schema already exists in your database. Do **not** re-import the schema unless setting up a fresh database. Edit `backend/config.php` if you choose another username/password.

## 2. Copy into Apache web root
Extract the project, then copy its contents into `/var/www/html/doctor-appointment-system`. For example, if you downloaded the ZIP to Windows Downloads, copy it into WSL first and extract it there. Ensure `index.php`, `frontend/`, `backend/`, and `database/` are directly inside the project directory.

```bash
sudo chown -R www-data:www-data /var/www/html/doctor-appointment-system
sudo chmod -R 755 /var/www/html/doctor-appointment-system
```

## 3. Create the first admin
From the project directory run:

```bash
php backend/create_admin.php "System Admin" admin@example.com 'ReplaceWithAStrongPassword123!'
```

Use your chosen email/password at login. Do not expose `backend/create_admin.php` through the web; it refuses non-CLI execution.

## 4. Open the website
Visit `http://localhost/doctor-appointment-system/` in your browser. If Apache is not running: `sudo service apache2 start`.

## 5. Suggested test order
1. Login as admin and create a doctor.
2. Log in as that doctor and set weekly schedule.
3. Sign up as a patient in another browser/incognito session.
4. Browse doctors and book a future slot.
5. Test cancellation and review appointment status as doctor/admin.

## Notes / limitations
- This is a learning-project baseline, not a production medical application. Add HTTPS, rate limiting, audit logs, stronger deployment secrets, automated tests, and production security review before public deployment.
- Existing generated slots are retained to preserve appointment history. If a doctor changes their schedule, already generated slots are not automatically removed or blocked; review future slot management before using this for real patients.
- The UI uses Google Fonts if internet access is available; it falls back to system fonts.

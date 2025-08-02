 Gate Pass App – Architecture Overview
📱 1. Home Page
UI Elements:

🔒 Login Button

⋮ Three-dot menu (top-right)

   → View History Page


🔐 2. Login Page (Universal Login)
Input Fields:

Email or ID

Password

Logic:

Firebase Authentication

Check user's role from Firestore after login:

dart
Copy
Edit
FirebaseAuth.instance.currentUser.uid
→ fetch from `users` collection
→ role = 'admin' / 'student' / 'security'
Routing After Login:

admin → AdminDashboard

student → StudentDashboard

security → SecurityDashboard



🧑‍💼 3. Admin Dashboard
Options:

➕ Add Student

Add Name, Email, roll number,parent phone number,parent name.

Save to users collection and create Firebase Auth account

📃 View Student List

Fetch from users where role = 'student'

📥 View Requested Gate Passes

Fetch from gate_pass_requests where status = Pending

Admin can Approve/Reject (update Firestore document)



🎓 4. Student Dashboard
Options:

📝 Request Gate Pass

Fields: Reason, From Date, To Date

Submit to gate_pass_requests with status = Pending

🧾 View My Gate Pass

Fetch from gate_pass_requests where student_id == currentUser

Show QR Code of request ID if status = Approved




🛡️ 5. Security Dashboard
Features:

📷 Scan QR Code

Use Flutter QR Scanner

Scan gate pass ID

Check in Firestore:

If valid and approved, show student details

Toggle button → In or Out

Update field: status = In / Out + time_stamp



🕓 6. View History Page
Accessed from:

Home Page (⋮ Three-dot button)

Shows:

Grouped by Date

Each entry shows:

Student Name

Reason

Status: In / Out

Timestamp

Color:

Green = Out (student is out)

Default = In (student is in hostel)


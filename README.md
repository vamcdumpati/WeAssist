# Patient Assistance App

## Overview
The Patient Assistance App is designed to help users manage their healthcare needs efficiently. Users can log in using their mobile number, sign up for an account, and verify their email to access various features of the application.

## Features
- User authentication via mobile number
- Sign up with mandatory fields: mobile number, name, and email
- Email verification to ensure account security
- Clean and user-friendly interface
- Toast notifications for user feedback

## Project Structure
```
patient-assistance-app
├── src
│   ├── components
│   │   ├── LoginPage.tsx
│   │   ├── SignUpPage.tsx
│   │   ├── VerificationToast.tsx
│   │   └── common
│   │       └── InputField.tsx
│   ├── firebase
│   │   └── firebaseConfig.ts
│   ├── hooks
│   │   └── useAuth.ts
│   ├── pages
│   │   ├── Home.tsx
│   │   └── Profile.tsx
│   ├── types
│   │   └── index.ts
│   ├── App.tsx
│   └── index.tsx
├── public
│   └── index.html
├── package.json
├── tsconfig.json
└── README.md
```

## Setup Instructions
1. Clone the repository:
   ```
   git clone <repository-url>
   ```
2. Navigate to the project directory:
   ```
   cd patient-assistance-app
   ```
3. Install the dependencies:
   ```
   npm install
   ```
4. Set up Firebase:
   - Create a Firebase project and obtain your configuration settings.
   - Update the `src/firebase/firebaseConfig.ts` file with your Firebase credentials.

5. Start the application:
   ```
   npm start
   ```

## Usage
- Users can log in using their mobile number.
- If a user does not have an account, they can sign up by providing their mobile number, name, and email.
- Email verification is required before logging in. If the email is not verified, a toast notification will prompt the user to complete the verification.

## Contributing
Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.

## License
This project is licensed under the MIT License.
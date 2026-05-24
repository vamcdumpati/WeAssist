export interface User {
    id: string;
    name: string;
    email: string;
    mobileNumber: string;
    emailVerified: boolean;
    phoneVerified: boolean;
}

export interface AuthResponse {
    user: User;
    token: string;
}

export interface SignUpData {
    name: string;
    email: string;
    mobileNumber: string;
}

export interface LoginData {
    mobileNumber: string;
}
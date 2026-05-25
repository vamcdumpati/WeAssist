export interface AdminUser {
    uid: string;
    firstName: string;
    lastName: string;
    email: string;
    mobileNumber: string;
    emailVerified: boolean;
    role?: string;
}

export interface Patient {
    id: string;
    name: string;
    patientMobile: string;
    dob: string;
    age: number;
    gender: string;
    height: string;
    weight: string;
    idPhotoUrl: string;
    patientPhotoUrl: string;
    createdAt: string;
}

export interface HospitalVisit {
    id: string;
    patientId: string;
    hospitalName: string;
    hospitalArea: string;
    location: {
        latitude: number | null;
        longitude: number | null;
        address?: string;
    };
    emergencyContact: string;
    createdAt: string;
}

export interface SignUpData {
    firstName: string;
    lastName: string;
    email: string;
    mobileNumber: string;
}

export interface LoginData {
    mobileNumber: string;
}
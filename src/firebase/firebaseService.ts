import { auth as realAuth, db as realDb } from "./firebaseConfig";
import { 
  signOut as realSignOut,
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  sendEmailVerification,
  signInWithPhoneNumber,
  RecaptchaVerifier,
  ConfirmationResult,
  User as FirebaseUser
} from "firebase/auth";
import { 
  collection, 
  doc, 
  setDoc, 
  getDoc, 
  getDocs, 
  query, 
  where, 
  addDoc 
} from "firebase/firestore";
import { getStorage, ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { AdminUser, Patient, HospitalVisit } from "../types";

// Determine if we should run in demo mode (local storage)
export const isDemoMode = (): boolean => {
  try {
    const authAny: any = realAuth;
    const config = authAny.app?.options;
    return !config || !config.apiKey || config.apiKey.includes("YOUR_API_KEY");
  } catch (e) {
    return true;
  }
};

// Log helper for demo mode
const demoLogs: string[] = [];
export const addDemoLog = (message: string) => {
  const timestamp = new Date().toLocaleTimeString();
  const logMsg = `[${timestamp}] ${message}`;
  demoLogs.push(logMsg);
  if (demoLogs.length > 50) demoLogs.shift();
  // Trigger custom event so components can update log viewer
  window.dispatchEvent(new CustomEvent("demo-log-update", { detail: demoLogs }));
};

export const getDemoLogs = () => [...demoLogs];

// -------------------------------------------------------------
// LOCAL STORAGE MOCK DB FOR DEMO MODE
// -------------------------------------------------------------
const getLocalAdmins = (): AdminUser[] => {
  const data = localStorage.getItem("weassist_demo_admins");
  return data ? JSON.parse(data) : [];
};

const saveLocalAdmins = (admins: AdminUser[]) => {
  localStorage.setItem("weassist_demo_admins", JSON.stringify(admins));
};

const getLocalPatients = (): Patient[] => {
  const data = localStorage.getItem("weassist_demo_patients");
  return data ? JSON.parse(data) : [];
};

const saveLocalPatients = (patients: Patient[]) => {
  localStorage.setItem("weassist_demo_patients", JSON.stringify(patients));
};

const getLocalVisits = (): HospitalVisit[] => {
  const data = localStorage.getItem("weassist_demo_visits");
  return data ? JSON.parse(data) : [];
};

const saveLocalVisits = (visits: HospitalVisit[]) => {
  localStorage.setItem("weassist_demo_visits", JSON.stringify(visits));
};

// Current Session in Demo Mode
let demoUserCallback: ((user: AdminUser | null) => void) | null = null;
let currentDemoUser: AdminUser | null = null;

// Initialize session from localStorage if present
const initDemoSession = () => {
  const data = localStorage.getItem("weassist_demo_current_user");
  if (data) {
    currentDemoUser = JSON.parse(data);
  }
};
initDemoSession();

// Temp storage for OTP codes in demo mode
let demoOTPCodes: Record<string, string> = {};

// -------------------------------------------------------------
// EXPORTED UNIFIED SERVICES
// -------------------------------------------------------------

export const authService = {
  // Listen to auth state changes
  onAuthChange: (callback: (user: AdminUser | null) => void) => {
    if (isDemoMode()) {
      demoUserCallback = callback;
      callback(currentDemoUser);
      return () => {
        demoUserCallback = null;
      };
    } else {
      // Live Firebase
      return realAuth.onAuthStateChanged(async (firebaseUser) => {
        if (!firebaseUser) {
          callback(null);
          return;
        }

        // If authenticated (could be via phone or email temporarily)
        // Find corresponding user in Firestore
        try {
          // Check Firestore admins collection
          const userDoc = await getDoc(doc(realDb, "admins", firebaseUser.uid));
          if (userDoc.exists()) {
            const adminData = userDoc.data();
            callback({
              uid: firebaseUser.uid,
              firstName: adminData.firstName || "",
              lastName: adminData.lastName || "",
              email: adminData.email || "",
              mobileNumber: adminData.mobileNumber || "",
              emailVerified: firebaseUser.emailVerified,
              role: adminData.role || "care taker"
            });
          } else {
            // Document might not exist yet if they just signed up or are anonymous
            callback({
              uid: firebaseUser.uid,
              firstName: "Admin",
              lastName: "",
              email: firebaseUser.email || "",
              mobileNumber: firebaseUser.phoneNumber || "",
              emailVerified: firebaseUser.emailVerified
            });
          }
        } catch (err) {
          console.error("Error fetching admin doc:", err);
          callback(null);
        }
      });
    }
  },

  // Admin Sign Up
  signUp: async (firstName: string, lastName: string, email: string, mobileNumber: string, role: string): Promise<void> => {
    if (isDemoMode()) {
      addDemoLog(`Registration requested for: ${firstName} ${lastName}`);
      const admins = getLocalAdmins();
      
      // Check if mobile or email already exists
      if (admins.some(a => a.mobileNumber === mobileNumber)) {
        throw new Error("Mobile number is already registered.");
      }
      if (admins.some(a => a.email.toLowerCase() === email.toLowerCase())) {
        throw new Error("Email address is already registered.");
      }

      const newAdmin: AdminUser = {
        uid: "demo_user_" + Math.random().toString(36).substr(2, 9),
        firstName,
        lastName,
        email,
        mobileNumber,
        emailVerified: false,
        role: role
      };

      admins.push(newAdmin);
      saveLocalAdmins(admins);
      addDemoLog(`Account created (${role}). Verification email sent to: ${email}`);
      addDemoLog(`[SIMULATION] Check the console or Dashboard to verify this email.`);
      return;
    } else {
      // Live Mode:
      // We will create the user with email + mobileNumber as password in Auth
      // to trigger verification email.
      const querySnapshot = await getDocs(
        query(collection(realDb, "admins"), where("mobileNumber", "==", mobileNumber))
      );
      
      if (!querySnapshot.empty) {
        throw new Error("Mobile number is already registered in WeAssist.");
      }

      const userCredential = await createUserWithEmailAndPassword(realAuth, email, mobileNumber);
      const user = userCredential.user;

      if (user) {
        // Send email verification
        await sendEmailVerification(user);

        // Store admin details in Firestore
        await setDoc(doc(realDb, "admins", user.uid), {
          firstName,
          lastName,
          email,
          mobileNumber,
          emailVerified: false,
          role,
          createdAt: new Date().toISOString()
        });

        // Sign out right away, as they must verify email first
        await realSignOut(realAuth);
      }
    }
  },

  // Pre-Login check: verifies mobile number is registered and email is verified
  checkEmailVerification: async (mobileNumber: string): Promise<{ isVerified: boolean; email: string }> => {
    if (isDemoMode()) {
      const admins = getLocalAdmins();
      const admin = admins.find(a => a.mobileNumber === mobileNumber);
      
      if (!admin) {
        throw new Error("This mobile number is not registered. Please sign up first.");
      }

      // Restrict login: care takers cannot login from web portal
      if (admin.role !== "super admin" && admin.role !== "admin") {
        throw new Error("Access denied. Care takers cannot login from the web portal.");
      }

      return {
        isVerified: admin.emailVerified,
        email: admin.email
      };
    } else {
      // Live Mode:
      // 1. Query Firestore for the email associated with this mobileNumber
      const q = query(collection(realDb, "admins"), where("mobileNumber", "==", mobileNumber));
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        throw new Error("This mobile number is not registered. Please sign up first.");
      }

      const adminDoc = querySnapshot.docs[0];
      const adminData = adminDoc.data();
      const email = adminData.email;

      // Restrict login: care takers cannot login from web portal
      if (adminData.role !== "super admin" && adminData.role !== "admin") {
        throw new Error("Access denied. Care takers cannot login from the web portal.");
      }

      // 2. Perform a silent email/password sign-in to check emailVerified state
      try {
        const userCredential = await signInWithEmailAndPassword(realAuth, email, mobileNumber);
        const user = userCredential.user;
        const isVerified = user.emailVerified;

        // If verified, update our Firestore document cache
        if (isVerified && !adminData.emailVerified) {
          await setDoc(doc(realDb, "admins", user.uid), { emailVerified: true }, { merge: true });
        }

        // Sign out immediately so we can transition to Phone OTP auth
        await realSignOut(realAuth);

        return {
          isVerified,
          email
        };
      } catch (err) {
        const error: any = err;
        if (error.code === 'auth/wrong-password' || error.code === 'auth/user-not-found') {
          throw new Error("Authentication cache issue. Please contact support.");
        }
        throw new Error(error.message || "Failed checking email verification.");
      }
    }
  },

  // Phone OTP Flow: sends SMS code to phone number
  sendOTP: async (
    mobileNumber: string, 
    recaptchaContainerId: string
  ): Promise<ConfirmationResult | string> => {
    // Standardize phone number format for firebase phone auth (requires + country code, e.g. +91 for India, +1 for US)
    // If not starting with +, we assume Indian number (+91) as default, or user input.
    let formattedPhone = mobileNumber;
    if (!formattedPhone.startsWith("+")) {
      if (formattedPhone.length === 10) {
        formattedPhone = "+91" + formattedPhone;
      } else {
        formattedPhone = "+" + formattedPhone;
      }
    }

    if (isDemoMode()) {
      // Generate a mock code
      const mockCode = Math.floor(100000 + Math.random() * 900000).toString();
      demoOTPCodes[mobileNumber] = mockCode;
      
      addDemoLog(`[OTP SERVICE] Generating SMS code for ${mobileNumber}`);
      addDemoLog(`[OTP SERVICE] SMS SENT to ${mobileNumber}: "Your WeAssist login OTP is ${mockCode}"`);
      
      // Show alert so user knows the OTP code
      alert(`[DEMO MODE] SMS sent to ${mobileNumber}\nOTP Code: ${mockCode}`);
      return mobileNumber; // Return phone as verificationId placeholder
    } else {
      // Live Mode
      const recaptchaVerifier = new RecaptchaVerifier(recaptchaContainerId, {
        size: "invisible",
        callback: () => {
          // reCAPTCHA solved, can proceed with signInWithPhoneNumber.
        }
      }, realAuth);

      const confirmationResult = await signInWithPhoneNumber(realAuth, formattedPhone, recaptchaVerifier);
      return confirmationResult;
    }
  },

  // Confirm Phone OTP Code
  confirmOTP: async (
    verificationObj: ConfirmationResult | string, 
    otpCode: string, 
    mobileNumber: string
  ): Promise<AdminUser> => {
    if (isDemoMode()) {
      const savedCode = demoOTPCodes[mobileNumber];
      if (savedCode && savedCode === otpCode) {
        const admins = getLocalAdmins();
        const admin = admins.find(a => a.mobileNumber === mobileNumber);
        
        if (!admin) {
          throw new Error("Admin not found.");
        }

        currentDemoUser = admin;
        localStorage.setItem("weassist_demo_current_user", JSON.stringify(admin));
        
        addDemoLog(`Admin logged in successfully: ${admin.firstName} ${admin.lastName}`);
        
        if (demoUserCallback) {
          demoUserCallback(currentDemoUser);
        }
        return admin;
      } else {
        addDemoLog(`[OTP ERROR] Invalid OTP code: ${otpCode}`);
        throw new Error("Invalid verification code. Please try again.");
      }
    } else {
      // Live Mode
      if (typeof verificationObj === "string") {
        throw new Error("Invalid confirmation object.");
      }
      const userCredential = await verificationObj.confirm(otpCode);
      const user = userCredential.user;

      if (!user) {
        throw new Error("Verification failed.");
      }

      // Fetch user profile from Firestore
      // We search by mobileNumber query since uid for phone auth might differ from email auth uid
      const q = query(collection(realDb, "admins"), where("mobileNumber", "==", mobileNumber));
      const querySnapshot = await getDocs(q);

      let adminProfile: AdminUser;
      if (!querySnapshot.empty) {
        const adminData = querySnapshot.docs[0].data();
        adminProfile = {
          uid: user.uid,
          firstName: adminData.firstName || "",
          lastName: adminData.lastName || "",
          email: adminData.email || "",
          mobileNumber: adminData.mobileNumber || "",
          emailVerified: true,
          role: adminData.role || "care taker"
        };
      } else {
        adminProfile = {
          uid: user.uid,
          firstName: "Admin",
          lastName: "",
          email: "",
          mobileNumber: mobileNumber,
          emailVerified: true,
          role: "care taker"
        };
      }
      return adminProfile;
    }
  },

  // Log out
  logout: async (): Promise<void> => {
    if (isDemoMode()) {
      currentDemoUser = null;
      localStorage.removeItem("weassist_demo_current_user");
      addDemoLog("Admin logged out.");
      if (demoUserCallback) {
        demoUserCallback(null);
      }
      return;
    } else {
      await realSignOut(realAuth);
    }
  },

  // Demo helper: allows toggling email verified status from UI for testing
  simulateEmailVerification: (mobileNumber: string) => {
    if (isDemoMode()) {
      const admins = getLocalAdmins();
      const adminIdx = admins.findIndex(a => a.mobileNumber === mobileNumber);
      if (adminIdx !== -1) {
        admins[adminIdx].emailVerified = true;
        saveLocalAdmins(admins);
        addDemoLog(`[SIMULATION] Email for ${admins[adminIdx].email} marked as VERIFIED.`);
        if (currentDemoUser && currentDemoUser.mobileNumber === mobileNumber) {
          currentDemoUser.emailVerified = true;
          localStorage.setItem("weassist_demo_current_user", JSON.stringify(currentDemoUser));
          if (demoUserCallback) demoUserCallback(currentDemoUser);
        }
        return true;
      }
    }
    return false;
  }
};

// -------------------------------------------------------------
// FIRESTORE & STORAGE SERVICES
// -------------------------------------------------------------

export const databaseService = {
  // Add Patient
  addPatient: async (patientData: Omit<Patient, "id" | "createdAt">): Promise<Patient> => {
    const id = "pat_" + Math.random().toString(36).substr(2, 9);
    const createdAt = new Date().toISOString();
    const newPatient: Patient = {
      id,
      createdAt,
      ...patientData
    };

    if (isDemoMode()) {
      const patients = getLocalPatients();
      patients.push(newPatient);
      saveLocalPatients(patients);
      addDemoLog(`Patient registered: ${newPatient.name} (Age: ${newPatient.age})`);
      return newPatient;
    } else {
      // Live Mode
      await setDoc(doc(realDb, "patients", id), newPatient);
      return newPatient;
    }
  },

  // Get Patients
  getPatients: async (): Promise<Patient[]> => {
    if (isDemoMode()) {
      return getLocalPatients().sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    } else {
      // Live Mode
      const snap = await getDocs(collection(realDb, "patients"));
      const list: Patient[] = [];
      snap.forEach(docSnap => {
        const item: any = docSnap.data();
        list.push(item);
      });
      return list.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    }
  },

  // Add Hospital Visit
  addHospitalVisit: async (visitData: Omit<HospitalVisit, "id" | "createdAt">): Promise<HospitalVisit> => {
    const id = "visit_" + Math.random().toString(36).substr(2, 9);
    const createdAt = new Date().toISOString();
    const newVisit: HospitalVisit = {
      id,
      createdAt,
      ...visitData
    };

    if (isDemoMode()) {
      const visits = getLocalVisits();
      visits.push(newVisit);
      saveLocalVisits(visits);
      
      const patients = getLocalPatients();
      const patient = patients.find(p => p.id === visitData.patientId);
      addDemoLog(`Trip scheduled for ${patient?.name || "Patient"}: ${visitData.hospitalName} (${visitData.hospitalArea})`);
      return newVisit;
    } else {
      // Live Mode
      await setDoc(doc(realDb, "visits", id), newVisit);
      return newVisit;
    }
  },

  // Get Hospital Visits for a Patient
  getHospitalVisits: async (patientId: string): Promise<HospitalVisit[]> => {
    if (isDemoMode()) {
      return getLocalVisits()
        .filter(v => v.patientId === patientId)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    } else {
      // Live Mode
      const q = query(collection(realDb, "visits"), where("patientId", "==", patientId));
      const snap = await getDocs(q);
      const list: HospitalVisit[] = [];
      snap.forEach(docSnap => {
        const item: any = docSnap.data();
        list.push(item);
      });
      return list.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    }
  }
};

export const storageService = {
  // Upload Image File or Base64 String
  uploadImage: async (fileOrBase64: File | string, path: string): Promise<string> => {
    if (isDemoMode()) {
      addDemoLog(`Uploading image file to path: ${path}`);
      // In demo mode, if it's a File, convert it to Base64, otherwise return it directly
      if (typeof fileOrBase64 === "string") {
        return fileOrBase64;
      }
      
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onloadend = () => {
          const res: any = reader.result;
          resolve(res);
        };
        reader.onerror = reject;
        reader.readAsDataURL(fileOrBase64);
      });
    } else {
      // Live Mode
      const storage = getStorage();
      const storageRef = ref(storage, path);
      
      let blob: Blob;
      if (typeof fileOrBase64 === "string") {
        // Base64 Data URL to Blob conversion
        const response = await fetch(fileOrBase64);
        blob = await response.blob();
      } else {
        blob = fileOrBase64;
      }

      await uploadBytes(storageRef, blob);
      const downloadUrl = await getDownloadURL(storageRef);
      return downloadUrl;
    }
  }
};

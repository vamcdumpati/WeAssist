import React, { useState, useRef, useEffect } from 'react';
import InputField from './common/InputField';
import { databaseService, storageService, addDemoLog } from '../firebase/firebaseService';
import { Patient, HospitalVisit } from '../types';

interface PatientRegistrationProps {
    onComplete: () => void;
}

const PatientRegistration: React.FC<PatientRegistrationProps> = ({ onComplete }) => {
    // Wizard Steps: 1 = Details, 2 = Photos, 3 = Visit, 4 = Trip Active
    const [step, setStep] = useState<1 | 2 | 3 | 4>(1);
    const [loading, setLoading] = useState(false);

    // Step 1: Patient Personal Details
    const [name, setName] = useState('');
    const [patientMobile, setPatientMobile] = useState('');
    const [dob, setDob] = useState('');
    const [age, setAge] = useState<number | ''>('');
    const [gender, setGender] = useState('Male');
    const [height, setHeight] = useState('');
    const [weight, setWeight] = useState('');

    // Step 2: Photo Capture
    const [idPhoto, setIdPhoto] = useState<string | null>(null);
    const [patientPhoto, setPatientPhoto] = useState<string | null>(null);
    const [cameraActive, setCameraActive] = useState<'id' | 'patient' | null>(null);
    const [cameraError, setCameraError] = useState<string | null>(null);

    // Step 3: Hospital Transit Details
    const [hospitalName, setHospitalName] = useState('');
    const [hospitalArea, setHospitalArea] = useState('');
    const [lat, setLat] = useState<number | null>(null);
    const [lng, setLng] = useState<number | null>(null);
    const [locationAddress, setLocationAddress] = useState('');
    const [fetchingLocation, setFetchingLocation] = useState(false);
    const [emergencyContact, setEmergencyContact] = useState('');

    // Step 4: Active Trip Details
    const [activeTrip, setActiveTrip] = useState<{
        patientName: string;
        patientMobile: string;
        emergencyMobile: string;
        hospital: string;
        hospitalArea: string;
        lat: number;
        lng: number;
        mapLink: string;
        smsContent: string;
    } | null>(null);

    // Camera video & canvas references
    const videoRef = useRef<HTMLVideoElement | null>(null);
    const canvasRef = useRef<HTMLCanvasElement | null>(null);
    const streamRef = useRef<MediaStream | null>(null);

    // Auto-calculate Age based on DOB
    useEffect(() => {
        if (!dob) {
            setAge('');
            return;
        }
        
        const birthDate = new Date(dob);
        const today = new Date();
        
        let calculatedAge = today.getFullYear() - birthDate.getFullYear();
        const monthDiff = today.getMonth() - birthDate.getMonth();
        
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
            calculatedAge--;
        }
        
        setAge(calculatedAge >= 0 ? calculatedAge : 0);
    }, [dob]);

    // Request Location Coordinates
    const fetchCurrentLocation = () => {
        if (!navigator.geolocation) {
            alert("Geolocation is not supported by your browser.");
            return;
        }

        setFetchingLocation(true);
        navigator.geolocation.getCurrentPosition(
            (position) => {
                setLat(position.coords.latitude);
                setLng(position.coords.longitude);
                setFetchingLocation(false);
                addDemoLog(`Location fetched: Lat ${position.coords.latitude.toFixed(4)}, Lng ${position.coords.longitude.toFixed(4)}`);
            },
            (error) => {
                console.error("Location error:", error);
                setFetchingLocation(false);
                // Fallback coordinates for demo purposes
                setLat(12.9716);
                setLng(77.5946);
                setLocationAddress("Bengaluru, Karnataka (Mock Location)");
                addDemoLog("Location permission denied/failed. Used default coordinates.");
            },
            { enableHighAccuracy: true, timeout: 5000 }
        );
    };

    // Camera Handlers
    const startCamera = async (type: 'id' | 'patient') => {
        setCameraActive(type);
        setCameraError(null);
        
        try {
            if (streamRef.current) {
                streamRef.current.getTracks().forEach(track => track.stop());
            }

            const stream = await navigator.mediaDevices.getUserMedia({
                video: { facingMode: 'environment', width: { ideal: 640 }, height: { ideal: 480 } }
            });
            
            streamRef.current = stream;
            if (videoRef.current) {
                videoRef.current.srcObject = stream;
            }
        } catch (err) {
            const error: any = err;
            console.error("Camera access failed:", error);
            setCameraError("Camera access denied or unavailable. Please use the file upload option.");
            setCameraActive(null);
        }
    };

    const stopCamera = () => {
        if (streamRef.current) {
            streamRef.current.getTracks().forEach(track => track.stop());
            streamRef.current = null;
        }
        setCameraActive(null);
    };

    const capturePhoto = () => {
        if (videoRef.current && canvasRef.current && cameraActive) {
            const video = videoRef.current;
            const canvas = canvasRef.current;
            const context = canvas.getContext('2d');

            if (context) {
                canvas.width = video.videoWidth;
                canvas.height = video.videoHeight;
                context.drawImage(video, 0, 0, canvas.width, canvas.height);
                
                const dataUrl = canvas.toDataURL('image/jpeg', 0.85);
                
                if (cameraActive === 'id') {
                    setIdPhoto(dataUrl);
                } else {
                    setPatientPhoto(dataUrl);
                }
                
                stopCamera();
                addDemoLog(`Captured live photo for ${cameraActive === 'id' ? 'ID Proof' : 'Patient'}`);
            }
        }
    };

    const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>, type: 'id' | 'patient') => {
        const file = e.target.files?.[0];
        if (file) {
            const reader = new FileReader();
            reader.onloadend = () => {
                const dataUrl: any = reader.result;
                if (type === 'id') {
                    setIdPhoto(dataUrl);
                } else {
                    setPatientPhoto(dataUrl);
                }
                addDemoLog(`Uploaded photo for ${type === 'id' ? 'ID Proof' : 'Patient'}`);
            };
            reader.readAsDataURL(file);
        }
    };

    // Form Submission Actions
    const handleRegisterPatient = async (e: React.FormEvent) => {
        e.preventDefault();
        
        // Validations
        if (!name.trim() || !patientMobile.trim() || !dob || !gender || !height || !weight) {
            alert("Please fill in all mandatory details in Step 1.");
            setStep(1);
            return;
        }

        if (!idPhoto || !patientPhoto) {
            alert("Both identity proof and patient photo are required.");
            setStep(2);
            return;
        }

        setStep(3); // Proceed to hospital visit setup
    };

    // Start Transit Trip Flow
    const handleStartTrip = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!hospitalName.trim() || !hospitalArea.trim() || !emergencyContact.trim()) {
            alert("Please fill in all transit details.");
            return;
        }

        setLoading(true);
        try {
            // 1. Upload photos (handles base64 to storage, or keeps as base64 in demo mode)
            const idPhotoAny: any = idPhoto;
            const patientPhotoAny: any = patientPhoto;
            const idPhotoUrl = await storageService.uploadImage(idPhotoAny, `id_proofs/${name}_${Date.now()}.jpg`);
            const patientPhotoUrl = await storageService.uploadImage(patientPhotoAny, `patients/${name}_${Date.now()}.jpg`);

            // 2. Register Patient record
            const registeredPatient = await databaseService.addPatient({
                name,
                patientMobile,
                dob,
                age: Number(age),
                gender,
                height,
                weight,
                idPhotoUrl,
                patientPhotoUrl
            });

            // 3. Register Hospital Visit record
            const locationData = {
                latitude: lat || 12.9716, // fallback
                longitude: lng || 77.5946,
                address: locationAddress || "Registered Coordinates"
            };

            await databaseService.addHospitalVisit({
                patientId: registeredPatient.id,
                hospitalName,
                hospitalArea,
                location: locationData,
                emergencyContact
            });

            // 4. Generate Live Location Link (using current lat/lng coords)
            const currentLat = lat || 12.9716;
            const currentLng = lng || 77.5946;
            const googleMapsUrl = `https://www.google.com/maps?q=${currentLat},${currentLng}`;
            const messageBody = `WeAssist: Caretaker has started the transit trip for ${name} to ${hospitalName} (${hospitalArea}). Track live location: ${googleMapsUrl}`;

            // Store details for Step 4 view
            setActiveTrip({
                patientName: name,
                patientMobile: patientMobile,
                emergencyMobile: emergencyContact,
                hospital: hospitalName,
                hospitalArea: hospitalArea,
                lat: currentLat,
                lng: currentLng,
                mapLink: googleMapsUrl,
                smsContent: messageBody
            });

            // 5. Send Simulated Messages
            addDemoLog(`[ALERT TRANSMISSION] SMS dispatched to Patient (${patientMobile}): "${messageBody}"`);
            addDemoLog(`[ALERT TRANSMISSION] SMS dispatched to Emergency Contact (${emergencyContact}): "${messageBody}"`);
            
            // Increment Step to active transit screen
            setStep(4);
        } catch (err) {
            const error: any = err;
            alert("Error registering trip: " + error.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="main-content" style={{ display: 'block', maxWidth: '800px', margin: '0 auto' }}>
            <div className="glass-card wide">
                <h2>New Patient Intake</h2>
                <p className="subtitle">Register patient bio-metrics and schedule immediate transit</p>

                {/* Progress Indicators */}
                <div className="wizard-steps">
                    <div className={`wizard-step ${step >= 1 ? 'completed' : ''} ${step === 1 ? 'active' : ''}`}>1</div>
                    <div className={`wizard-step ${step >= 2 ? 'completed' : ''} ${step === 2 ? 'active' : ''}`}>2</div>
                    <div className={`wizard-step ${step >= 3 ? 'completed' : ''} ${step === 3 ? 'active' : ''}`}>3</div>
                    <div className={`wizard-step ${step >= 4 ? 'completed' : ''} ${step === 4 ? 'active' : ''}`}>4</div>
                </div>

                {/* Step 1: Patient Bio Details */}
                {step === 1 && (
                    <form onSubmit={handleRegisterPatient}>
                        <h3>Step 1: Patient Profile Details</h3>
                        <div className="form-row">
                            <InputField
                                label="Patient Name"
                                type="text"
                                value={name}
                                onChange={(e) => setName(e.target.value)}
                                required
                            />
                            <InputField
                                label="Patient Mobile Number"
                                type="tel"
                                value={patientMobile}
                                onChange={(e) => setPatientMobile(e.target.value)}
                                required
                            />
                        </div>

                        <div className="form-row">
                            <InputField
                                label="Date of Birth"
                                type="date"
                                value={dob}
                                onChange={(e) => setDob(e.target.value)}
                                required
                            />
                            <InputField
                                label="Auto-Calculated Age"
                                type="text"
                                value={age.toString()}
                                onChange={() => {}}
                                required
                            />
                        </div>

                        <div className="form-row">
                            <div className="form-group">
                                <label>Gender</label>
                                <select value={gender} onChange={(e) => setGender(e.target.value)}>
                                    <option>Male</option>
                                    <option>Female</option>
                                    <option>Other</option>
                                </select>
                            </div>
                            <div className="form-row" style={{ gap: '0.5rem' }}>
                                <InputField
                                    label="Height (cm)"
                                    type="number"
                                    value={height}
                                    onChange={(e) => setHeight(e.target.value)}
                                    required
                                />
                                <InputField
                                    label="Weight (kg)"
                                    type="number"
                                    value={weight}
                                    onChange={(e) => setWeight(e.target.value)}
                                    required
                                />
                            </div>
                        </div>

                        <button type="submit" className="btn-primary" style={{ marginTop: '1.5rem' }}>
                            Next: Photos Upload & Capture →
                        </button>
                    </form>
                )}

                {/* Step 2: Camera Photo Capture */}
                {step === 2 && (
                    <div>
                        <h3>Step 2: Capture Photos</h3>
                        <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem', fontSize: '0.9rem' }}>
                            Please upload or take a live photo of the patient's identity proof card and a portrait shot.
                        </p>

                        <div className="form-row" style={{ gap: '2rem' }}>
                            {/* Identity Photo Area */}
                            <div style={{ textAlign: 'center' }}>
                                <label style={{ display: 'block', marginBottom: '0.5rem' }}>1. Identity Proof Document</label>
                                {idPhoto ? (
                                    <div style={{ position: 'relative', marginBottom: '1rem' }}>
                                        <img src={idPhoto} alt="ID Proof" style={{ width: '100%', maxHeight: '200px', objectFit: 'cover', borderRadius: 'var(--radius-md)', border: '2px solid var(--glass-border)' }} />
                                        <button type="button" className="btn-secondary" style={{ position: 'absolute', bottom: '10px', right: '10px', width: 'auto', padding: '0.4rem 0.8rem', fontSize: '0.8rem' }} onClick={() => setIdPhoto(null)}>Retake</button>
                                    </div>
                                ) : (
                                    <div>
                                        <div className="file-upload-fallback" onClick={() => startCamera('id')}>
                                            <div style={{ fontSize: '1.8rem', marginBottom: '0.5rem' }}>📷</div>
                                            <span>Start Live Camera</span>
                                            <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>or click here to select a file</p>
                                            <input type="file" accept="image/*" id="id-upload-input" onClick={(e) => e.stopPropagation()} onChange={(e) => handleFileUpload(e, 'id')} />
                                            <label htmlFor="id-upload-input" style={{ cursor: 'pointer', color: 'var(--primary)', textTransform: 'none', display: 'block', marginTop: '0.5rem', fontSize: '0.8rem' }}>Browse files</label>
                                        </div>
                                    </div>
                                )}
                            </div>

                            {/* Patient Photo Area */}
                            <div style={{ textAlign: 'center' }}>
                                <label style={{ display: 'block', marginBottom: '0.5rem' }}>2. Patient Portrait Photo</label>
                                {patientPhoto ? (
                                    <div style={{ position: 'relative', marginBottom: '1rem' }}>
                                        <img src={patientPhoto} alt="Patient Portrait" style={{ width: '100%', maxHeight: '200px', objectFit: 'cover', borderRadius: 'var(--radius-md)', border: '2px solid var(--glass-border)' }} />
                                        <button type="button" className="btn-secondary" style={{ position: 'absolute', bottom: '10px', right: '10px', width: 'auto', padding: '0.4rem 0.8rem', fontSize: '0.8rem' }} onClick={() => setPatientPhoto(null)}>Retake</button>
                                    </div>
                                ) : (
                                    <div>
                                        <div className="file-upload-fallback" onClick={() => startCamera('patient')}>
                                            <div style={{ fontSize: '1.8rem', marginBottom: '0.5rem' }}>👤</div>
                                            <span>Start Portrait Camera</span>
                                            <p style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '0.25rem' }}>or click here to select a file</p>
                                            <input type="file" accept="image/*" id="pat-upload-input" onClick={(e) => e.stopPropagation()} onChange={(e) => handleFileUpload(e, 'patient')} />
                                            <label htmlFor="pat-upload-input" style={{ cursor: 'pointer', color: 'var(--primary)', textTransform: 'none', display: 'block', marginTop: '0.5rem', fontSize: '0.8rem' }}>Browse files</label>
                                        </div>
                                    </div>
                                )}
                            </div>
                        </div>

                        {/* Inline Camera Overlay / Action */}
                        {cameraActive && (
                            <div style={{ marginTop: '2rem', padding: '1.5rem', background: 'rgba(0,0,0,0.5)', borderRadius: 'var(--radius-lg)', border: '1px solid var(--glass-border)' }}>
                                <h4>Live Camera Feed: {cameraActive === 'id' ? 'ID Document' : 'Patient Portrait'}</h4>
                                {cameraError && <p style={{ color: 'var(--error)' }}>{cameraError}</p>}
                                <div className="camera-container">
                                    <video ref={videoRef} autoPlay playsInline className="camera-video"></video>
                                    <canvas ref={canvasRef} className="camera-canvas"></canvas>
                                </div>
                                <div className="camera-actions">
                                    <button type="button" className="btn-success" onClick={capturePhoto}>Capture Photo</button>
                                    <button type="button" className="btn-secondary" onClick={stopCamera}>Cancel</button>
                                </div>
                            </div>
                        )}

                        <div className="form-row" style={{ marginTop: '2.5rem', gridTemplateColumns: '120px 1fr' }}>
                            <button type="button" className="btn-secondary" onClick={() => setStep(1)}>
                                Back
                            </button>
                            <button 
                                type="button" 
                                className="btn-primary" 
                                disabled={!idPhoto || !patientPhoto}
                                onClick={() => setStep(3)}
                            >
                                Next: Hospital Details Setup →
                            </button>
                        </div>
                    </div>
                )}

                {/* Step 3: Transit Booking Form */}
                {step === 3 && (
                    <form onSubmit={handleStartTrip}>
                        <h3>Step 3: Transit Details</h3>
                        <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem', fontSize: '0.9rem' }}>
                            Enter destination details, obtain current coordinate location, and verify emergency numbers.
                        </p>

                        <div className="form-row">
                            <InputField
                                label="Hospital Name"
                                type="text"
                                value={hospitalName}
                                onChange={(e) => setHospitalName(e.target.value)}
                                required
                            />
                            <InputField
                                label="Hospital Location Area"
                                type="text"
                                value={hospitalArea}
                                onChange={(e) => setHospitalArea(e.target.value)}
                                required
                            />
                        </div>

                        <div className="form-group">
                            <label>Patient Pickup Location</label>
                            <div className="form-row" style={{ gridTemplateColumns: '1fr 140px', gap: '0.5rem', marginBottom: '0.5rem' }}>
                                <input 
                                    type="text" 
                                    value={locationAddress || (lat && lng ? `${lat.toFixed(6)}, ${lng.toFixed(6)}` : '')}
                                    placeholder="Click locate button to capture GPS coords, or enter address..."
                                    onChange={(e) => setLocationAddress(e.target.value)}
                                />
                                <button type="button" className="btn-secondary" style={{ padding: '0.5rem' }} onClick={fetchCurrentLocation} disabled={fetchingLocation}>
                                    {fetchingLocation ? 'Locating...' : '📍 Fetch GPS'}
                                </button>
                            </div>
                            {lat && lng && (
                                <p style={{ fontSize: '0.8rem', color: 'var(--success)' }}>
                                    Latitude: {lat.toFixed(6)} | Longitude: {lng.toFixed(6)} (GPS coordinates captured successfully)
                                </p>
                            )}
                        </div>

                        <InputField
                            label="Emergency Contact Number (SMS notification target)"
                            type="tel"
                            value={emergencyContact}
                            onChange={(e) => setEmergencyContact(e.target.value)}
                            required
                        />

                        <div className="form-row" style={{ marginTop: '2.5rem', gridTemplateColumns: '120px 1fr' }}>
                            <button type="button" className="btn-secondary" onClick={() => setStep(2)} disabled={loading}>
                                Back
                            </button>
                            <button 
                                type="submit" 
                                className="btn-success" 
                                disabled={loading}
                                style={{ fontSize: '1.05rem', padding: '1rem' }}
                            >
                                {loading ? 'Processing Intake...' : '🚀 Start to Hospital'}
                            </button>
                        </div>
                    </form>
                )}

                {/* Step 4: Active Trip / Transit Status */}
                {step === 4 && activeTrip && (
                    <div className="trip-active-card">
                        <div className="trip-status-badge">🟢 Transit Active</div>
                        
                        <div className="pulse-location-icon">
                            📍
                        </div>

                        <h2>Trip Started to Hospital</h2>
                        <p style={{ color: 'var(--text-secondary)', maxWidth: '500px', margin: '0 auto 1.5rem', fontSize: '0.95rem' }}>
                            The WeAssist caretaker is currently transporting patient <strong>{activeTrip.patientName}</strong> to <strong>{activeTrip.hospital} ({activeTrip.hospitalArea})</strong>.
                        </p>

                        {/* Interactive map button */}
                        <div style={{ marginBottom: '2rem' }}>
                            <a 
                                href={activeTrip.mapLink} 
                                target="_blank" 
                                rel="noreferrer" 
                                className="btn-primary" 
                                style={{ display: 'inline-flex', width: 'auto', textDecoration: 'none', gap: '0.5rem' }}
                            >
                                Open Current GPS Location in Maps 🗺️
                            </a>
                        </div>

                        {/* Simulated SMS Dispatch log */}
                        <div className="trip-message-log">
                            <h4>📲 Dispatch Alerts Delivered</h4>
                            <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                                <p>Alert notifications containing live maps tracking links have been sent via SMS to:</p>
                                <ul style={{ marginLeft: '1.25rem', marginTop: '0.5rem', marginBottom: '1rem' }}>
                                    <li>Patient number: <strong>{activeTrip.patientMobile}</strong></li>
                                    <li>Emergency contact: <strong>{activeTrip.emergencyMobile}</strong></li>
                                </ul>
                            </div>
                            
                            <label>SMS Body Content</label>
                            <div className="message-bubble">
                                WeAssist: Caretaker has started the transit trip for {activeTrip.patientName} to {activeTrip.hospital} ({activeTrip.hospitalArea}). Track live location: <span className="highlight">{activeTrip.mapLink}</span>
                            </div>
                        </div>

                        {/* Native SMS Trigger Link fallback */}
                        <div style={{ display: 'flex', gap: '1rem', marginTop: '2rem' }}>
                            <a 
                                href={`sms:${activeTrip.patientMobile}?body=${encodeURIComponent(activeTrip.smsContent)}`} 
                                className="btn-secondary" 
                                style={{ display: 'inline-flex', flex: '1', textDecoration: 'none' }}
                            >
                                Send Patient SMS Native
                            </a>
                            <a 
                                href={`sms:${activeTrip.emergencyMobile}?body=${encodeURIComponent(activeTrip.smsContent)}`} 
                                className="btn-secondary" 
                                style={{ display: 'inline-flex', flex: '1', textDecoration: 'none' }}
                            >
                                Send Emergency SMS Native
                            </a>
                        </div>

                        <button 
                            type="button" 
                            className="btn-success" 
                            style={{ marginTop: '2rem', background: '#047857' }}
                            onClick={() => {
                                alert("Transit trip completed. Patient safely dropped off.");
                                addDemoLog(`Transit completed for ${activeTrip.patientName}. Drop-off successful.`);
                                onComplete();
                            }}
                        >
                            ✓ Mark Drop-off & Complete Visit
                        </button>
                    </div>
                )}
            </div>
        </div>
    );
};

export default PatientRegistration;

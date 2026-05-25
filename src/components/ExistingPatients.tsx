import React, { useState, useEffect } from 'react';
import InputField from './common/InputField';
import { databaseService, storageService, addDemoLog } from '../firebase/firebaseService';
import { Patient, HospitalVisit } from '../types';

const ExistingPatients: React.FC = () => {
    const [patients, setPatients] = useState<Patient[]>([]);
    const [filteredPatients, setFilteredPatients] = useState<Patient[]>([]);
    const [searchQuery, setSearchQuery] = useState('');
    const [selectedPatient, setSelectedPatient] = useState<Patient | null>(null);
    const [visitHistory, setVisitHistory] = useState<HospitalVisit[]>([]);
    const [loading, setLoading] = useState(false);
    
    // Booking Form State
    const [bookingActive, setBookingActive] = useState(false);
    const [hospitalName, setHospitalName] = useState('');
    const [hospitalArea, setHospitalArea] = useState('');
    const [lat, setLat] = useState<number | null>(null);
    const [lng, setLng] = useState<number | null>(null);
    const [locationAddress, setLocationAddress] = useState('');
    const [fetchingLocation, setFetchingLocation] = useState(false);
    const [emergencyContact, setEmergencyContact] = useState('');

    // Transit Trip Active State
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

    // Initial load
    useEffect(() => {
        loadPatients();
    }, []);

    // Filter patients based on query
    useEffect(() => {
        if (!searchQuery.trim()) {
            setFilteredPatients(patients);
            return;
        }

        const query = searchQuery.toLowerCase();
        const filtered = patients.filter(
            p => p.name.toLowerCase().includes(query) || p.patientMobile.includes(query)
        );
        setFilteredPatients(filtered);
    }, [searchQuery, patients]);

    // Load visit history when patient is selected
    useEffect(() => {
        if (selectedPatient) {
            loadVisitHistory(selectedPatient.id);
            // Reset booking form
            setBookingActive(false);
            setHospitalName('');
            setHospitalArea('');
            setLat(null);
            setLng(null);
            setLocationAddress('');
            setEmergencyContact('');
        }
    }, [selectedPatient]);

    const loadPatients = async () => {
        setLoading(true);
        try {
            const data = await databaseService.getPatients();
            setPatients(data);
            setFilteredPatients(data);
        } catch (err) {
            const error: any = err;
            alert("Error loading patients directory: " + error.message);
        } finally {
            setLoading(false);
        }
    };

    const loadVisitHistory = async (patientId: string) => {
        try {
            const data = await databaseService.getHospitalVisits(patientId);
            setVisitHistory(data);
        } catch (err) {
            const error: any = err;
            console.error("Error loading visits:", error);
        }
    };

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
                setLat(12.9716);
                setLng(77.5946);
                setLocationAddress("Bengaluru, Karnataka (Mock Location)");
                addDemoLog("Location permission denied/failed. Used default coordinates.");
            },
            { enableHighAccuracy: true, timeout: 5000 }
        );
    };

    // Booking Submission
    const handleStartTrip = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!selectedPatient) return;
        if (!hospitalName.trim() || !hospitalArea.trim() || !emergencyContact.trim()) {
            alert("Please fill in all transit details.");
            return;
        }

        setLoading(true);
        try {
            const locationData = {
                latitude: lat || 12.9716,
                longitude: lng || 77.5946,
                address: locationAddress || "Transit Coords"
            };

            // Register Hospital Visit record in Database
            await databaseService.addHospitalVisit({
                patientId: selectedPatient.id,
                hospitalName,
                hospitalArea,
                location: locationData,
                emergencyContact
            });

            // Generate Map Link & Message
            const currentLat = lat || 12.9716;
            const currentLng = lng || 77.5946;
            const googleMapsUrl = `https://www.google.com/maps?q=${currentLat},${currentLng}`;
            const messageBody = `WeAssist: Caretaker has started the transit trip for ${selectedPatient.name} to ${hospitalName} (${hospitalArea}). Track live location: ${googleMapsUrl}`;

            // Set trip details
            setActiveTrip({
                patientName: selectedPatient.name,
                patientMobile: selectedPatient.patientMobile,
                emergencyMobile: emergencyContact,
                hospital: hospitalName,
                hospitalArea: hospitalArea,
                lat: currentLat,
                lng: currentLng,
                mapLink: googleMapsUrl,
                smsContent: messageBody
            });

            // Send messages
            addDemoLog(`[ALERT TRANSMISSION] SMS dispatched to Patient (${selectedPatient.patientMobile}): "${messageBody}"`);
            addDemoLog(`[ALERT TRANSMISSION] SMS dispatched to Emergency Contact (${emergencyContact}): "${messageBody}"`);

        } catch (err) {
            const error: any = err;
            alert("Error scheduling trip: " + error.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="main-content" style={{ display: 'block', maxWidth: '960px', margin: '0 auto' }}>
            <div className="glass-card wide">
                {activeTrip ? (
                    // Transit view (Step 4 equivalent)
                    <div className="trip-active-card" style={{ maxWidth: '720px', margin: '0 auto' }}>
                        <div className="trip-status-badge">🟢 Transit Active</div>
                        
                        <div className="pulse-location-icon">
                            📍
                        </div>

                        <h2>Trip Started to Hospital</h2>
                        <p style={{ color: 'var(--text-secondary)', maxWidth: '500px', margin: '0 auto 1.5rem', fontSize: '0.95rem' }}>
                            The WeAssist caretaker is currently transporting patient <strong>{activeTrip.patientName}</strong> to <strong>{activeTrip.hospital} ({activeTrip.hospitalArea})</strong>.
                        </p>

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
                                alert("Transit trip completed successfully!");
                                addDemoLog(`Transit completed for ${activeTrip.patientName}. Drop-off successful.`);
                                setActiveTrip(null);
                                setBookingActive(false);
                                if (selectedPatient) {
                                    loadVisitHistory(selectedPatient.id);
                                }
                            }}
                        >
                            ✓ Mark Drop-off & Complete Visit
                        </button>
                    </div>
                ) : selectedPatient ? (
                    // Patient Detail view & booking
                    <div>
                        <div className="back-link" onClick={() => setSelectedPatient(null)}>
                            <span>←</span> Back to Patients Directory
                        </div>

                        <h2>Patient Dossier</h2>
                        <p className="subtitle">Review record file details or initiate transit booking</p>

                        {!bookingActive ? (
                            <div className="patient-details-grid">
                                <div className="details-photos">
                                    <div className="details-photo-box">
                                        <img src={selectedPatient.patientPhotoUrl} alt="Patient portrait" />
                                        <label>Patient portrait</label>
                                    </div>
                                    <div className="details-photo-box">
                                        <img src={selectedPatient.idPhotoUrl} alt="ID Document" />
                                        <label>Identity Proof</label>
                                    </div>
                                </div>

                                <div className="details-info-box">
                                    <h3 style={{ borderBottom: '1px solid var(--glass-border)', paddingBottom: '0.5rem', marginBottom: '1.25rem' }}>
                                        {selectedPatient.name}
                                    </h3>

                                    <div className="details-row">
                                        <div className="details-item">
                                            <label>Patient Mobile</label>
                                            <span>{selectedPatient.patientMobile}</span>
                                        </div>
                                        <div className="details-item">
                                            <label>Gender</label>
                                            <span>{selectedPatient.gender}</span>
                                        </div>
                                    </div>

                                    <div className="details-row">
                                        <div className="details-item">
                                            <label>Date of Birth</label>
                                            <span>{selectedPatient.dob}</span>
                                        </div>
                                        <div className="details-item">
                                            <label>Age</label>
                                            <span>{selectedPatient.age} years</span>
                                        </div>
                                    </div>

                                    <div className="details-row">
                                        <div className="details-item">
                                            <label>Height</label>
                                            <span>{selectedPatient.height} cm</span>
                                        </div>
                                        <div className="details-item">
                                            <label>Weight</label>
                                            <span>{selectedPatient.weight} kg</span>
                                        </div>
                                    </div>

                                    <button 
                                        type="button" 
                                        className="btn-primary" 
                                        style={{ marginTop: '1.5rem' }}
                                        onClick={() => setBookingActive(true)}
                                    >
                                        📅 Book New Hospital Transit
                                    </button>

                                    {/* Visits History List */}
                                    <div style={{ marginTop: '2.5rem' }}>
                                        <h4 style={{ fontSize: '1rem', borderBottom: '1px solid var(--glass-border)', paddingBottom: '0.25rem', marginBottom: '0.75rem' }}>
                                            Hospital Visit Logs
                                        </h4>
                                        {visitHistory.length === 0 ? (
                                            <p style={{ color: 'var(--text-muted)', fontSize: '0.85rem' }}>
                                                No transit trips recorded yet for this patient.
                                            </p>
                                        ) : (
                                            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', maxHeight: '180px', overflowY: 'auto' }}>
                                                {visitHistory.map((visit) => (
                                                    <div key={visit.id} style={{ background: 'rgba(255,255,255,0.02)', border: '1px solid var(--glass-border)', borderRadius: 'var(--radius-sm)', padding: '0.75rem', fontSize: '0.85rem' }}>
                                                        <div className="flex-between" style={{ fontWeight: '600', color: '#ffffff' }}>
                                                            <span>🏥 {visit.hospitalName}</span>
                                                            <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                                                                {new Date(visit.createdAt).toLocaleDateString()}
                                                            </span>
                                                        </div>
                                                        <div style={{ color: 'var(--text-secondary)', marginTop: '0.25rem' }}>
                                                            Area: {visit.hospitalArea} | Emergency Contact: {visit.emergencyContact}
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        )}
                                    </div>
                                </div>
                            </div>
                        ) : (
                            // Book Visit Subform
                            <form onSubmit={handleStartTrip} style={{ maxWidth: '600px', margin: '0 auto' }}>
                                <h3>Transit Setup for {selectedPatient.name}</h3>
                                <p style={{ color: 'var(--text-secondary)', marginBottom: '1.5rem', fontSize: '0.9rem' }}>
                                    Schedule a visit to the hospital and trigger real-time transit status sharing.
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
                                            placeholder="Fetch coordinates or type address..."
                                            onChange={(e) => setLocationAddress(e.target.value)}
                                        />
                                        <button type="button" className="btn-secondary" style={{ padding: '0.5rem' }} onClick={fetchCurrentLocation} disabled={fetchingLocation}>
                                            {fetchingLocation ? 'Locating...' : '📍 Fetch GPS'}
                                        </button>
                                    </div>
                                    {lat && lng && (
                                        <p style={{ fontSize: '0.8rem', color: 'var(--success)' }}>
                                            Coords: {lat.toFixed(6)}, {lng.toFixed(6)}
                                        </p>
                                    )}
                                </div>

                                <InputField
                                    label="Emergency Contact Number"
                                    type="tel"
                                    value={emergencyContact}
                                    onChange={(e) => setEmergencyContact(e.target.value)}
                                    required
                                />

                                <div className="form-row" style={{ marginTop: '2.5rem', gridTemplateColumns: '120px 1fr' }}>
                                    <button type="button" className="btn-secondary" onClick={() => setBookingActive(false)} disabled={loading}>
                                        Cancel
                                    </button>
                                    <button 
                                        type="submit" 
                                        className="btn-success" 
                                        disabled={loading}
                                        style={{ fontSize: '1.05rem', padding: '1rem' }}
                                    >
                                        {loading ? 'Scheduling...' : '🚀 Start to Hospital'}
                                    </button>
                                </div>
                            </form>
                        )}
                    </div>
                ) : (
                    // Patient Directory list
                    <div>
                        <h2>Patients Directory</h2>
                        <p className="subtitle">Search and manage existing patient records</p>

                        <div className="search-bar">
                            <span className="search-icon">🔍</span>
                            <input
                                type="text"
                                placeholder="Search patients by name or phone..."
                                value={searchQuery}
                                onChange={(e) => setSearchQuery(e.target.value)}
                            />
                        </div>

                        {loading ? (
                            <div style={{ textAlign: 'center', padding: '3rem 0', color: 'var(--text-secondary)' }}>
                                Loading patients records...
                            </div>
                        ) : filteredPatients.length === 0 ? (
                            <div style={{ textAlign: 'center', padding: '4rem 0', color: 'var(--text-muted)' }}>
                                📂 No patients found matching your search.
                            </div>
                        ) : (
                            <div className="patient-list">
                                {filteredPatients.map(patient => (
                                    <div 
                                        key={patient.id} 
                                        className="patient-card"
                                        onClick={() => setSelectedPatient(patient)}
                                    >
                                        <img 
                                            src={patient.patientPhotoUrl} 
                                            alt={patient.name} 
                                            className="patient-avatar" 
                                            onError={(e) => {
                                                // fallback avatar
                                                const target: any = e.target;
                                                target.src = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='60' height='60' fill='%236b7280'%3E%3Cpath d='M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z'/%3E%3C/svg%3E";
                                            }}
                                        />
                                        <div className="patient-info">
                                            <div className="patient-name">{patient.name}</div>
                                            <div className="patient-meta">
                                                <span>📱 {patient.patientMobile}</span>
                                                <span>•</span>
                                                <span>🎂 {patient.age} yrs ({patient.gender})</span>
                                            </div>
                                        </div>
                                        <button 
                                            type="button" 
                                            className="btn-primary patient-action-btn"
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                setSelectedPatient(patient);
                                            }}
                                        >
                                            View dossier
                                        </button>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
};

export default ExistingPatients;

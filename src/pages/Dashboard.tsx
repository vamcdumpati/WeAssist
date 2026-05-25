import React, { useState } from 'react';
import useAuth from '../hooks/useAuth';
import ExistingPatients from '../components/ExistingPatients';
import * as LucideIcons from 'react-icons/lu';

const LuLayoutDashboard: any = LucideIcons.LuLayoutDashboard;
const LuUsers: any = LucideIcons.LuUsers;
const LuUserCog: any = LucideIcons.LuUserCog;
const LuCreditCard: any = LucideIcons.LuCreditCard;
const LuLogOut: any = LucideIcons.LuLogOut;
const LuCircleCheck: any = LucideIcons.LuCircleCheck;
const LuClock: any = LucideIcons.LuClock;
const LuEllipsisVertical: any = LucideIcons.LuEllipsisVertical;
const LuUserPlus: any = LucideIcons.LuUserPlus;
const LuMoreVertical: any = LucideIcons.LuEllipsisVertical;


type ViewType = 'dashboard' | 'users' | 'caretakers' | 'payments' | 'existing-patients';

interface Order {
  id: string;
  patientName: string;
  status: 'new' | 'in-progress' | 'completed';
  date: string;
  assignedCaretaker?: string;
}

const DUMMY_ORDERS: Order[] = [
  { id: 'ORD-001', patientName: 'John Doe', status: 'new', date: '2026-05-25' },
  { id: 'ORD-002', patientName: 'Jane Smith', status: 'in-progress', date: '2026-05-25', assignedCaretaker: 'Alice Johnson' },
  { id: 'ORD-003', patientName: 'Michael Brown', status: 'completed', date: '2026-05-24', assignedCaretaker: 'Bob Williams' },
  { id: 'ORD-004', patientName: 'Sarah Davis', status: 'new', date: '2026-05-25' },
];

const DUMMY_CARETAKERS = ['Alice Johnson', 'Bob Williams', 'Charlie Davis'];

const Dashboard: React.FC = () => {
    const { user, logout } = useAuth();
    const [view, setView] = useState<ViewType>('dashboard');
    const [orders, setOrders] = useState<Order[]>(DUMMY_ORDERS);
    const [assigningOrderId, setAssigningOrderId] = useState<string | null>(null);

    const handleLogout = async () => {
        if (window.confirm("Are you sure you want to sign out?")) {
            await logout();
            window.location.href = '/';
        }
    };

    const handleAssign = (orderId: string, caretaker: string) => {
        setOrders(orders.map(o => 
            o.id === orderId ? { ...o, status: 'in-progress', assignedCaretaker: caretaker } : o
        ));
        setAssigningOrderId(null);
    };

    const newOrdersCount = orders.filter(o => o.status === 'new').length;
    const inProgressCount = orders.filter(o => o.status === 'in-progress').length;
    const completedCount = orders.filter(o => o.status === 'completed').length;

    const renderSidebar = () => (
        <aside className="admin-sidebar">
            <div className="sidebar-header">
                <div className="logo-container">
                    <div className="logo-icon">WA</div>
                    <div className="logo-text">WeAssist Admin</div>
                </div>
            </div>
            
            <div className="sidebar-profile">
                <div className="profile-avatar">
                    {user?.firstName?.charAt(0) || 'A'}
                </div>
                <div className="profile-info">
                    <div className="profile-name">Welcome, {user?.firstName}</div>
                    <div className="profile-role">{user?.role || 'Administrator'}</div>
                </div>
            </div>

            <nav className="sidebar-nav">
                <button className={`sidebar-link ${view === 'dashboard' ? 'active' : ''}`} onClick={() => setView('dashboard')}>
                    <LuLayoutDashboard size={20} />
                    <span>Dashboard</span>
                </button>
                <button className={`sidebar-link ${view === 'users' ? 'active' : ''}`} onClick={() => setView('users')}>
                    <LuUsers size={20} />
                    <span>User Management</span>
                </button>
                <button className={`sidebar-link ${view === 'caretakers' ? 'active' : ''}`} onClick={() => setView('caretakers')}>
                    <LuUserCog size={20} />
                    <span>Manage Care Takers</span>
                </button>
                <button className={`sidebar-link ${view === 'payments' ? 'active' : ''}`} onClick={() => setView('payments')}>
                    <LuCreditCard size={20} />
                    <span>Payments Dashboard</span>
                </button>
            </nav>

            <div className="sidebar-footer">
                <button className="sidebar-link logout" onClick={handleLogout}>
                    <LuLogOut size={20} />
                    <span>Sign Out</span>
                </button>
            </div>
        </aside>
    );

    const renderDashboardView = () => (
        <div className="dashboard-content animate-fade-in">
            <header className="content-header">
                <div>
                    <h1>Dashboard Overview</h1>
                    <p className="text-secondary">Track orders, manage bookings, and assign caretakers.</p>
                </div>
                <div className="header-actions">
                    <button className="btn-secondary" onClick={() => setView('existing-patients')}>
                        Patient Directory
                    </button>
                </div>
            </header>

            <div className="metrics-grid">
                <div className="metric-card">
                    <div className="metric-icon bg-primary-light">
                        <LuLayoutDashboard size={24} className="text-primary" />
                    </div>
                    <div className="metric-info">
                        <p className="metric-label">New Orders</p>
                        <h3 className="metric-value">{newOrdersCount}</h3>
                    </div>
                </div>
                <div className="metric-card">
                    <div className="metric-icon bg-warning-light">
                        <LuClock size={24} className="text-warning" />
                    </div>
                    <div className="metric-info">
                        <p className="metric-label">In Progress</p>
                        <h3 className="metric-value">{inProgressCount}</h3>
                    </div>
                </div>
                <div className="metric-card">
                    <div className="metric-icon bg-success-light">
                        <LuCircleCheck size={24} className="text-success" />
                    </div>
                    <div className="metric-info">
                        <p className="metric-label">Completed</p>
                        <h3 className="metric-value">{completedCount}</h3>
                    </div>
                </div>
            </div>

            <div className="table-container glass-panel mt-8">
                <div className="table-header">
                    <h2>Recent Orders</h2>
                </div>
                <div className="table-responsive">
                    <table className="admin-table">
                        <thead>
                            <tr>
                                <th>Order ID</th>
                                <th>Patient Name</th>
                                <th>Date</th>
                                <th>Status</th>
                                <th>Assigned Caretaker</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {orders.map(order => (
                                <tr key={order.id}>
                                    <td className="font-medium">{order.id}</td>
                                    <td>{order.patientName}</td>
                                    <td>{order.date}</td>
                                    <td>
                                        <span className={`status-badge status-${order.status}`}>
                                            {order.status === 'new' ? 'New' : 
                                             order.status === 'in-progress' ? 'In Progress' : 'Completed'}
                                        </span>
                                    </td>
                                    <td>{order.assignedCaretaker || <span className="text-muted">— Unassigned —</span>}</td>
                                    <td>
                                        {order.status === 'new' ? (
                                            <div className="assign-dropdown-container">
                                                <button 
                                                    className="btn-assign"
                                                    onClick={() => setAssigningOrderId(assigningOrderId === order.id ? null : order.id)}
                                                >
                                                    <LuUserPlus size={16} /> Assign
                                                </button>
                                                {assigningOrderId === order.id && (
                                                    <div className="assign-dropdown glass-card shadow-lg">
                                                        <p className="dropdown-title">Assign Caretaker</p>
                                                        <div className="caretaker-list">
                                                            {DUMMY_CARETAKERS.map(ct => (
                                                                <button 
                                                                    key={ct} 
                                                                    className="caretaker-option"
                                                                    onClick={() => handleAssign(order.id, ct)}
                                                                >
                                                                    {ct}
                                                                </button>
                                                            ))}
                                                        </div>
                                                    </div>
                                                )}
                                            </div>
                                        ) : (
                                            <button className="btn-icon">
                                                <LuEllipsisVertical size={18} />
                                            </button>
                                        )}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    );

    const renderPlaceholder = (title: string) => (
        <div className="dashboard-content animate-fade-in placeholder-view">
            <h1>{title}</h1>
            <p className="text-secondary mt-4">This module is under construction.</p>
        </div>
    );

    return (
        <div className="admin-layout">
            {renderSidebar()}
            
            <main className="admin-main">
                {view === 'dashboard' && renderDashboardView()}
                {view === 'users' && renderPlaceholder('User Management')}
                {view === 'caretakers' && renderPlaceholder('Manage Care Takers')}
                {view === 'payments' && renderPlaceholder('Payments Dashboard')}

                {view === 'existing-patients' && (
                    <div className="dashboard-content animate-fade-in">
                        <div className="back-link mb-6" onClick={() => setView('dashboard')}>
                            <span>←</span> Back to Dashboard
                        </div>
                        <ExistingPatients />
                    </div>
                )}
            </main>
        </div>
    );
};

export default Dashboard;

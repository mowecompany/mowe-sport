import { Route, Routes } from "react-router-dom";

import IndexPage from "@/pages/index";
import { ProtectedRoute } from "@/components/ProtectedRoute";
import { AuthLoader } from "@/components/AuthLoader";
// Auth pages
import SignInPage from "@/auth/sign-in/sign-in";
import SignUpPage from "@/auth/sign-up/sign-up";
// Main pages
import SportsPage from "@/pages/main/sports";
// eslint-disable-next-line import/order
import TeamsPage from "@/pages/main/teams";

// Administration pages
import AdminsPage from "@/pages/administration/admins";
import SuperAdminPage from "@/pages/administration/super_admin";
import PlayersPage from "@/pages/administration/players";
import UsersPage from "@/pages/administration/users";
import RefereesPage from "./pages/administration/referees";

// Profile and Settings pages
import ProfilePage from "@/pages/profile/ProfilePage";
import SettingsPage from "@/pages/settings/SettingsPage";

function App() {
  return (
    <AuthLoader>
      <Routes>
      {/* Auth routes - Manejan su propia lógica de redirección */}
      <Route path="/" element={<SignInPage />} />
      <Route path="/auth/sign-up" element={<SignUpPage />} />
      
      {/* Dashboard route - Requiere autenticación */}
      <Route 
        path="/dashboard" 
        element={
          <ProtectedRoute requireAuth={true}>
            <IndexPage />
          </ProtectedRoute>
        } 
      />
      
      {/* Main routes - Requieren autenticación */}
      <Route 
        path="/main/sports" 
        element={
          <ProtectedRoute requireAuth={true}>
            <SportsPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/main/teams" 
        element={
          <ProtectedRoute requireAuth={true}>
            <TeamsPage />
          </ProtectedRoute>
        } 
      />

      {/* Administration routes - Requieren autenticación */}
      <Route 
        path="/administration/super_admin" 
        element={
          <ProtectedRoute requireAuth={true}>
            <SuperAdminPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/administration/admins" 
        element={
          <ProtectedRoute requireAuth={true}>
            <AdminsPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/administration/players" 
        element={
          <ProtectedRoute requireAuth={true}>
            <PlayersPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/administration/referees" 
        element={
          <ProtectedRoute requireAuth={true}>
            <RefereesPage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/administration/users" 
        element={
          <ProtectedRoute requireAuth={true}>
            <UsersPage />
          </ProtectedRoute>
        } 
      />

      {/* Profile and Settings routes - Requieren autenticación */}
      <Route 
        path="/profile" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProfilePage />
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/settings" 
        element={
          <ProtectedRoute requireAuth={true}>
            <SettingsPage />
          </ProtectedRoute>
        } 
      />
      </Routes>
    </AuthLoader>
  );
}

export default App;

import { Route, Routes } from "react-router-dom";

import IndexPage from "@/pages/index";
import { ProtectedRoute } from "@/components/ProtectedRoute";
import { ProtectedPage } from "@/components/ProtectedPage";
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
import TournamentsPage from "./pages/main/tournaments";
import CalendarPage from "./pages/main/calendar";
import MatchesPage from "./pages/main/matches";
import StatisticsPage from "./pages/main/statistics";

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
      
      {/* Main routes - Requieren autenticación, accesibles para la mayoría de roles */}
      <Route 
        path="/main/sports" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client']}>
              <SportsPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/main/tournaments" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client']}>
              <TournamentsPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/main/teams" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'player', 'client']}>
              <TeamsPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/main/calendar" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client']}>
              <CalendarPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/main/matches" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client']}>
              <MatchesPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/main/statistics" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'player', 'client']}>
              <StatisticsPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />

      {/* Administration routes - Requieren autenticación y roles específicos */}
      <Route 
        path="/administration/super_admin" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin']}>
              <SuperAdminPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/administration/admins" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin']}>
              <AdminsPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/administration/players" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'owner', 'coach']}>
              <PlayersPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/administration/referees" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin']}>
              <RefereesPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/administration/users" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'owner']}>
              <UsersPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />

      {/* Profile and Settings routes - Requieren autenticación */}
      <Route 
        path="/profile" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'tournament_admin', 'owner', 'coach', 'referee', 'player', 'client']}>
              <ProfilePage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      <Route 
        path="/settings" 
        element={
          <ProtectedRoute requireAuth={true}>
            <ProtectedPage allowedRoles={['super_admin', 'city_admin', 'tournament_admin', 'owner']}>
              <SettingsPage />
            </ProtectedPage>
          </ProtectedRoute>
        } 
      />
      </Routes>
    </AuthLoader>
  );
}

export default App;

import { Route, Routes } from "react-router-dom";

import IndexPage from "@/pages/index";
// Auth pages
import SignInPage from "@/auth/sign-in/sign-in";
import SignUpPage from "@/auth/sign-up/sign-up";
// Main pages
import SportsPage from "@/pages/main/sports";
// eslint-disable-next-line import/order
import TeamsPage from "@/pages/main/teams";

// Administration pages
import AdminsPage from "@/pages/administration/admins";
import PlayersPage from "@/pages/administration/players";
import UsersPage from "@/pages/administration/users";

function App() {
  return (
    <Routes>
      {/* Auth routes */}
      <Route element={<SignInPage />} path="/" />
      <Route element={<SignUpPage />} path="/auth/sign-up" />
      
      {/* Dashboard route */}
      <Route element={<IndexPage />} path="/dashboard" />
      
      {/* Main routes */}
      <Route element={<SportsPage />} path="/main/sports" />
      <Route element={<TeamsPage />} path="/main/teams" />

      {/* Administration routes */}
      <Route element={<AdminsPage />} path="/administration/admins" />
      <Route element={<PlayersPage />} path="/administration/players" />
      <Route element={<UsersPage />} path="/administration/users" />
    </Routes>
  );
}

export default App;

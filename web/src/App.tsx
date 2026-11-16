import { Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "@/components/Layout";
import { RequireAuth } from "@/components/RequireAuth";
import IntegrationsPage from "@/pages/integrations/IntegrationsPage";
import StoreBoxSettings from "@/pages/integrations/StoreBoxSettings";
import Locations from "@/pages/Locations";
import Login from "@/pages/Login";
import ManageReturns from "@/pages/ManageReturns";
import ReturnDetail from "@/pages/ReturnDetail";
import Settings from "@/pages/Settings";

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route element={<RequireAuth />}>
        <Route element={<Layout />}>
          <Route path="/returns" element={<ManageReturns />} />
          <Route path="/returns/:id" element={<ReturnDetail />} />
          <Route path="/locations" element={<Locations />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/integrations" element={<IntegrationsPage />} />
          <Route path="/integrations/store-box" element={<StoreBoxSettings />} />
        </Route>
      </Route>
      <Route path="*" element={<Navigate to="/returns" replace />} />
    </Routes>
  );
}

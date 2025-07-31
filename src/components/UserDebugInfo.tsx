import { Card, CardBody, CardHeader } from "@heroui/card";
import { Button } from "@heroui/button";
import { useAuth } from "@/hooks/useAuth";
import { authService } from "@/services/auth";

export const UserDebugInfo = () => {
  const { user, forceRefresh } = useAuth();

  if (!import.meta.env.DEV) {
    return null;
  }

  const testProfileEndpoint = async () => {
    console.log('Testing profile endpoint...');
    try {
      const token = authService.getToken();
      console.log('Using token:', token);
      
      const response = await fetch('http://localhost:8080/api/auth/profile', {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });
      
      console.log('Response status:', response.status);
      console.log('Response headers:', response.headers);
      
      if (!response.ok) {
        const errorText = await response.text();
        console.error('Error response:', errorText);
        alert(`Error ${response.status}: ${errorText}`);
        return;
      }
      
      const data = await response.json();
      console.log('Profile endpoint response:', data);
      alert('Profile data received - check console');
    } catch (error) {
      console.error('Profile endpoint error:', error);
      alert('Network error - check console');
    }
  };

  const testAuthStatus = () => {
    console.log('=== AUTH STATUS DEBUG ===');
    console.log('Token:', authService.getToken());
    console.log('Current User:', authService.getCurrentUser());
    console.log('Is Authenticated:', authService.isAuthenticated());
    console.log('User from hook:', user);
    console.log('========================');
  };

  return (
    <Card className="mt-6 border-2 border-warning">
      <CardHeader>
        <h3 className="text-lg font-semibold text-warning">🐛 Debug Info (Development Only)</h3>
      </CardHeader>
      <CardBody>
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4 text-sm">
            <div>
              <strong>User ID:</strong> {user?.user_id || 'N/A'}
            </div>
            <div>
              <strong>Email:</strong> {user?.email || 'N/A'}
            </div>
            <div>
              <strong>First Name:</strong> "{user?.first_name || 'N/A'}" (exists: {user?.first_name ? '✅' : '❌'})
            </div>
            <div>
              <strong>Last Name:</strong> "{user?.last_name || 'N/A'}" (exists: {user?.last_name ? '✅' : '❌'})
            </div>
            <div>
              <strong>Primary Role:</strong> {user?.primary_role || 'N/A'}
            </div>
            <div>
              <strong>Account Status:</strong> {user?.account_status || 'N/A'}
            </div>
            <div>
              <strong>Phone:</strong> {user?.phone || 'N/A'}
            </div>
            <div>
              <strong>Identification:</strong> {user?.identification || 'N/A'}
            </div>
            <div>
              <strong>2FA Enabled:</strong> {user?.two_factor_enabled ? '✅' : '❌'}
            </div>
            <div>
              <strong>Failed Attempts:</strong> {user?.failed_login_attempts || 0}
            </div>
          </div>
          
          <div className="flex gap-2 flex-wrap">
            <Button size="sm" color="primary" onPress={forceRefresh}>
              🔄 Refresh User Data
            </Button>
            <Button size="sm" color="secondary" onPress={testProfileEndpoint}>
              🧪 Test Profile API
            </Button>
            <Button size="sm" color="warning" onPress={testAuthStatus}>
              📊 Log Auth Status
            </Button>
            <Button 
              size="sm" 
              color="danger" 
              variant="bordered"
              onPress={() => {
                authService.clearAllAuthData();
                window.location.reload();
              }}
            >
              🗑️ Clear All Auth Data
            </Button>
          </div>
          
          <div className="text-xs text-default-500 bg-default-100 p-2 rounded">
            <strong>Raw User Object:</strong>
            <pre className="mt-1 overflow-auto max-h-32">
              {JSON.stringify(user, null, 2)}
            </pre>
          </div>
        </div>
      </CardBody>
    </Card>
  );
};
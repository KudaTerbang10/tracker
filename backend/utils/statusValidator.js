const ROLE_SCAN_PERMISSIONS = {
  admin_cabang: ['diterima_cabang', 'keluar_cabang', 'hilang', 'gagal_kirim', 'diterima'],
  driver: ['diterima'],
  super_admin: ['kasus_selesai'],
};

function canRoleSetStatus(role, targetStatus) {
  return ROLE_SCAN_PERMISSIONS[role]?.includes(targetStatus) ?? false;
}

function getScanTypeForRole(role) {
  if (role === 'admin_cabang') return 'datang';
  if (role === 'driver') return 'diterima';
  return null;
}

module.exports = { canRoleSetStatus, ROLE_SCAN_PERMISSIONS, getScanTypeForRole };

const ROLE_SCAN_PERMISSIONS = {
  admin_konter: ['diterima_konter', 'keluar_konter'],
  staff_gudang: ['diterima_gudang', 'keluar_gudang'],
  admin_cabang: ['diterima_konter', 'keluar_konter', 'diterima_gudang', 'keluar_gudang'],
  driver: ['diterima'],
};

function canRoleSetStatus(role, targetStatus) {
  return ROLE_SCAN_PERMISSIONS[role]?.includes(targetStatus) ?? false;
}

function getScanTypeForRole(role) {
  if (role === 'admin_konter') return 'create';
  if (role === 'admin_cabang' || role === 'staff_gudang') return 'datang';
  if (role === 'driver') return 'diterima';
  return null;
}

module.exports = { canRoleSetStatus, ROLE_SCAN_PERMISSIONS, getScanTypeForRole };

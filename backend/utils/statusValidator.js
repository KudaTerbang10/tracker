const STATUS_TRANSITIONS = {
  admin_konter: {
    new: { next: 'diterima_konter', scanType: 'create' },
    diterima_konter: { next: 'keluar_konter', scanType: 'keluar' },
  },
  staff_gudang: {
    keluar_konter: { next: 'diterima_gudang', scanType: 'datang' },
    diterima_gudang: { next: 'keluar_gudang', scanType: 'keluar' },
    keluar_gudang: { next: 'diterima_gudang', scanType: 'datang' },
  },
  driver: {
    proses_kirim: { next: 'diterima', scanType: 'diterima' },
  },
};

function validateTransition(currentStatus, role) {
  const roleTransitions = STATUS_TRANSITIONS[role];
  if (!roleTransitions) return null;

  const key = currentStatus || 'new';
  const transition = roleTransitions[key];
  if (!transition) return null;

  return transition;
}

function getScanTypeForRole(role) {
  if (role === 'admin_konter') return 'create';
  if (role === 'staff_gudang') return 'datang';
  if (role === 'driver') return 'diterima';
  return null;
}

module.exports = { validateTransition, STATUS_TRANSITIONS, getScanTypeForRole };

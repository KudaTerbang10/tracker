const rbac = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ message: `Akses ditolak. Role ${req.user.role} tidak diizinkan` });
    }
    next();
  };
};

module.exports = rbac;

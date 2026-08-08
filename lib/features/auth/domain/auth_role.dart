/// Privilege role for the session (parity with `auth.js`: `sales` | `admin`).
///
/// `sales` is the default, unauthenticated role (billing + bills). `admin` is
/// unlocked with a PIN and grants access to the admin modules.
enum AuthRole {
  sales('sales'),
  admin('admin');

  const AuthRole(this.wire);

  final String wire;

  static AuthRole fromWire(Object? value) {
    return value?.toString().toLowerCase() == 'admin'
        ? AuthRole.admin
        : AuthRole.sales;
  }
}

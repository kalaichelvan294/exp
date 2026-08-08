/// Abstract interface for database operations.
/// Allows different implementations for native (Windows) and web platforms.
abstract class DbInterface {
  /// Initialize database connection.
  Future<void> connect();

  /// Execute a query and return rows as maps.
  /// Parameters are embedded directly in the SQL string.
  Future<List<Map<String, dynamic>>> query(String sql);

  /// Execute a command (INSERT/UPDATE/DELETE) and return affected row count.
  /// Parameters should be embedded in the SQL string directly.
  Future<int> execute(String sql);

  /// Begin a transaction.
  Future<void> begin();

  /// Commit a transaction.
  Future<void> commit();

  /// Rollback a transaction.
  Future<void> rollback();

  /// Close the connection.
  Future<void> close();
}

import 'dart:io' as io;

/// Result of a process execution
class ProcessRunResult {
  final int exitCode;
  final dynamic stdout;
  final dynamic stderr;

  const ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  /// Create from io.ProcessResult
  factory ProcessRunResult.fromProcessResult(io.ProcessResult result) {
    return ProcessRunResult(
      exitCode: result.exitCode,
      stdout: result.stdout,
      stderr: result.stderr,
    );
  }
}

/// Wrapper for Process.run to make it testable
abstract class ProcessRunner {
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments,
  );
}

/// Default implementation using actual Process.run
class DefaultProcessRunner implements ProcessRunner {
  const DefaultProcessRunner();

  @override
  Future<ProcessRunResult> run(
    String executable,
    List<String> arguments,
  ) async {
    final result = await io.Process.run(executable, arguments);
    return ProcessRunResult.fromProcessResult(result);
  }
}
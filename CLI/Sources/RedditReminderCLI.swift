import Foundation

@main
struct RedditReminderCLI {
  static func main() async {
    do {
      let arguments = Array(CommandLine.arguments.dropFirst())
      let invocation = try CLIInvocation(arguments: arguments)
      let runner = try CLIRunner(options: invocation.options)
      let response = try runner.run(command: invocation.command)
      CLIPrinter.print(response, options: invocation.options)
    } catch let error as CLIError {
      CLIPrinter.printError(error)
      Foundation.exit(Int32(error.exitCode))
    } catch {
      CLIPrinter.printError(.runtime(error.localizedDescription))
      Foundation.exit(1)
    }
  }
}

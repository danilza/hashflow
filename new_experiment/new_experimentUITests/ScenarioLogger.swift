import XCTest

final class ScenarioLogger {
    private let scenarioName: String
    private var stepIndex: Int = 0
    private var logLines: [String] = []

    init(_ scenarioName: String) {
        self.scenarioName = scenarioName
        let header = "[SCENARIO: \(scenarioName)]"
        logLines.append(header)
        print(header)
    }

    func reserveStep() -> Int {
        stepIndex += 1
        return stepIndex
    }

    func success(step: Int, description: String) {
        let line = String(format: "[STEP %02d] %@ - OK", step, description)
        logLines.append(line)
        print(line)
    }

    func fail(step: Int, description: String, expected: String, actual: String, file: StaticString = #file, line: UInt = #line) {
        let header = String(format: "[STEP %02d] %@ - FAILED", step, description)
        let expectedLine = "         Expected: \(expected)"
        let actualLine = "         Actual: \(actual)"
        print(header)
        print(expectedLine)
        print(actualLine)
        logLines.append(header)
        logLines.append(expectedLine)
        logLines.append(actualLine)
        XCTFail(logLines.joined(separator: "\n"), file: file, line: line)
    }
}

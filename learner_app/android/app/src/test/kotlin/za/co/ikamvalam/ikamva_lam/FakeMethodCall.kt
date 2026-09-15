package za.co.ikamvalam.ikamva_lam

import io.flutter.plugin.common.MethodCall

/**
 * Minimal [MethodCall] stand-in for unit tests.
 *
 * [MethodCall] is a simple data class with a public constructor, so we can
 * instantiate it directly without mocking.
 */
fun FakeMethodCall(method: String, arguments: Any?): MethodCall =
    MethodCall(method, arguments)

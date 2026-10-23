package io.github.danajerban.fuegoos.fakeapp

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

/** Stands in for the TV input player: shows "Playing <input ID>" for the passthrough input it was asked to open. */
class FakeInputPlayerActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(TextView(this).apply { text = "Playing ${intent.data?.lastPathSegment}" })
    }
}

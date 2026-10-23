package io.github.danajerban.fuegoos.fakeapp

import android.app.Activity
import android.os.Bundle
import android.widget.TextView

class FakeAppActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(TextView(this).apply { setText(R.string.app_name) })
    }
}

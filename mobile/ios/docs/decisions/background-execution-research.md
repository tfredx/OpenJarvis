# iOS workflow resumption research

| API | Documented behavior | Mobile increment |
| --- | --- | --- |
| App Intents, Siri and Shortcuts | The runtime selects a mode using the intent's supported modes and system context. A foreground transition must be available before the intent requests one. | The existing Ask Jarvis intent opens the app with a draft. Add a user-initiated resume intent only after durable task identity and safe recovery exist. |
| BackgroundTasks | The system chooses launch timing for deferred work. Processing can expire or be interrupted. Continued processing requests start with user-initiated work and remain subject to system scheduling and termination. | Evaluate checkpoint maintenance after durable storage exists. All resumable work must be interruptible and avoid replaying uncertain external writes. |
| Local notifications | Notifications present an alert or badge according to authorization and system delivery policy. | A future opt-in notification can offer a route back to an interrupted task. The foreground UI remains the approval boundary. |

Sources: [App Intents runtime behavior](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents), [background strategy selection](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app), [continued processing](https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados), [local notification scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).

For any prototype, record build, hardware, OS, lock state, requested versus actual start, expiration and whether resume recovered the same checkpoint. Current supported recovery is user-initiated in the foreground. Other execution paths are planned and unverified.

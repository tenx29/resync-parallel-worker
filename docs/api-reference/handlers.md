# Server & Client Handlers

In addition to the [`ThreadPool`](./thread-pool.md) class, Resync contains two scripts for executing tasks on the server and client side. These scripts are called `ServerHandler` and `ClientHandler`, respectively.

The server and client handlers are identical in functionality, the only difference being the context in which they are executed. The server handler is executed on the server, while the client handler is executed on the client. The scripts are responsible for the execution of tasks dispatched with Resync as well as communication between each thread and the thread pool. Modifying these scripts should not be necessary, as they are only used internally by the [`ThreadPool`](./thread-pool.md) class.

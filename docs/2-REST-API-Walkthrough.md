# Part 2: REST API Walkthrough

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Database Setup](#database-setup)
    - [Configure the Connection to the Database](#configure-the-connection-to-the-database)
    - [Load and Validate the Environment Variables](#load-and-validate-environment-variables)
    - [Creating a `run` function to initialize dependencies](#creating-a-run-function-to-initialize-dependencies)
    - [Connect to PostgreSQL](#connect-to-postgresql)
    - [Setting up User Model](#setting-up-user-model)
    - [Creating our User Service](#creating-our-user-service)
- [Service Setup](#service-setup)
    - [Handler setup](#handler-setup)
    - [Route Setup](#route-setup)
    - [Server setup](#server-setup-1)
    - [Adding a server to main.go](#adding-a-server-to-maingo)
- [Add Middleware](#add-middleware)
- [Generating Swagger Docs](#generating-swagger-docs)
- [Injecting the user service into the read user handler](#injecting-the-user-service-into-the-read-user-handler)
- [Hiding the read user response type](#hiding-the-read-user-response-type)
- [Reading the user and mapping it to a response](#reading-the-user-and-mapping-it-to-a-response)
- [Flesh out user CRUD routes / handlers](#flesh-out-user-crud-routes--handlers)
- [Input model validation](#input-model-validation)
- [Unit Testing](#unit-testing)
    - [Unit Testing Introduction](#unit-testing-introduction)
    - [Unit Testing in This Tech Challenge](#unit-testing-in-this-tech-challenge)
    - [Example: Handler unit test](#example-handler-unit-test)
    - [Example: Service unit test](#example-service-unit-test)
- [Next Steps](#next-steps)


## Overview

As previously mentioned, this challenge is centered around the use of the `net/http` library for
developing API's. Our web server will connect to a PostgreSQL database in the backend. This
walkthrough will consist of a step-by-step guide for creating the REST API for the `users` table in
the database. By the end of the walkthrough, you will have endpoints capable of creating, reading,
updating, and deleting from the `users` table.

## Project Structure

By default, you should see the following file structure in your root directory

```
.
├── cmd/
│   └── api/
│       └── main.go
├── internal/
│   ├── config/
│   │   └── config.go
│   ├── handlers
│   │   └── handlers.go
│   ├── routes/
│   │   └── routes.go
│   ├── models
│   │   └── models.go
│   ├── middleware
│   │   └── middleware.go
│   └── services/
│       └── user.go
├── .gitignore
├── Makefile
└── README.md
```

Before beginning to look through the project structure, ensure that you first understand the basics
of Go project structuring. As a good starting place, check
out [Organizing a Go Module](https://go.dev/doc/modules/layout) from the Go team. It is important to
note that one size does not fit all Go projects. Applications can be designed on a spectrum ranging
from very lean and flat layouts, to highly structured and nested layouts. This challenge will sit in
the middle, with a layout that can be applied to a broad set of Go applications.

The `cmd/` folder contains the entrypoint(s) for the application. For this Tech Challenge, we will
only need one entrypoint into the application, `api`.

The `cmd/api` folder contains the entrypoint code specific to setting up a webserver for our
application. This code should be very minimal and is primarily focused on initializing dependencies
for our application then starting the application.

The `internal/` folder contains internal packages that comprise the bulk of the application logic
for the challenge:

- `config` contains our application configuration
- `handlers` contains our http handlers which are the functions that execute when a request is sent
  to the application
- `models` contains domain models for the application
- `routes` contains our route definitions which map a URL to a handler
- `server` contains a constructor for a fully configured `http.Server`
- `services` contains our service layer which is responsible for our application logic

The `Makefile` contains various `make` commands that will be helpful throughout the project. We will
reference these as they are needed. Feel free to look through the `Makefile` to get an idea for
what's there or add your own make targets.

Now that you are familiar with the current structure of the project, we can begin connecting our
application to our database.

## Database Setup

We will first begin by setting up the database layer of our application.

### Configure the Connection to the Database

In order for the project to be able to connect to the PostgreSQL database, we first need to handle
configuration. During setup, we created a `.env` file to store environment variables. The values needed to connect to the database should already be there.

### Load and Validate Environment Variables

To handle loading environment variables into the application, we will utilize the [
`env`](https://github.com/caarlos0/env) package from `caarlos0` as well as the [
`godotenv`](https://github.com/joho/godotenv) package. You should have already installed these packages during setup.

`env` is used to parse values from our system environment variables and map them to properties on a
struct we've defined. `env` can also be used to perform validation on environment variables such as
ensuring they are defined and don't contain an empty value.

`godotenv` is used to load values from `.env` files into system environment variables. This allows
us to define these values in a `.env` file for local development.

First, lets add a few more values to the `.env` file:
```.env
HOST=localhost
PORT=8000
LOG_LEVEL=DEBUG
```

Now, find the `internal/config/config.go` file. This is where we'll define the struct to contain our
environment variables.

Add the struct definition below to the file below the existing package definition:

```go
// Config holds the application configuration settings. The configuration is loaded from
// environment variables.
type Config struct {
    DBHost         string     `env:"DATABASE_HOST,required"`
    DBUserName     string     `env:"DATABASE_USER,required"`
    DBUserPassword string     `env:"DATABASE_PASSWORD,required"`
    DBName         string     `env:"DATABASE_NAME,required"`
    DBPort         string     `env:"DATABASE_PORT,required"`
    Host           string     `env:"HOST,required"`
    Port           string     `env:"PORT,required"`
    LogLevel       slog.Level `env:"LOG_LEVEL,required"`
}
```

Now, add the following function to the file below the `Config` struct:

```go
// New loads configuration from environment variables and a .env file, and returns a
// Config struct or error.
func New() (Config, error) {
    // Load values from a .env file and add them to system environment variables.
    // Discard errors coming from this function. This allows us to call this
    // function without a .env file which will by default load values directly
    // from system environment variables.
    _ = godotenv.Load()

    // Once values have been loaded into system env vars, parse those into our
    // config struct and validate them returning any errors.
    cfg, err := env.ParseAs[Config]()
    if err != nil {
        return Config{}, fmt.Errorf("[in config.New] failed to parse config: %w", err)
    }

    return cfg, nil
}
```

In the above code, we created a function called `New()` that is responsible for loading the
environment variables from the `.env` file, validating them, and mapping them into our `Config`
struct. 

The `New` naming convention is widely established in Go, and is used when we are returning an
instance of an object from a package that shares the same name. Such as a `Config` object being
returned from a `config` package.

Note that we are using an underscore `_` to discard any posable errors from `godotenv.Load()` since we don't really care if there is an error and wont be handling the error if one was returned. Explicitly discarding errors when you don't want to handle them is considered a best practice as it signals to others that you meant to do this instead of just having forgotten to handle it.

### Creating a `run` function to initialize dependencies

Now that we can load config, let's take a step back and make an update to our `cmd/api/main.go`
file. One quirk of Go is that our `func main` can't return anything. Wouldn't it be nice if we could
return an error or a status code from `main` to signal that a dependency failed to initialize? We're
going to steal a pattern popularized by Matt Ryer to do exactly that.

First, in `cmd/api/main.go` we're going to add the `run` function below the `main()` function definition. It should contain logic to call `config.New()` and initialize a logger. The `run()` function will be responsible for initializing all our dependencies and starting our application:

```go
func run(ctx context.Context) error {
    // Load and validate environment config
    cfg, err := config.New()
    if err != nil {
        return fmt.Errorf("[in main.run] failed to load config: %w", err)
    }
    
    // Create a structured logger, which will print logs in json format to the
    // writer we specify.
    logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: cfg.LogLevel,
    }))

    return nil
}
```

Next, we'll update `func main` to look like this:

```go
func main() {
    ctx := context.Background()
    if err := run(ctx); err != nil {
        _, _ = fmt.Fprintf(os.Stderr, "server encountered an error: %s\n", err)
        os.Exit(1)
    }
}
```

Now our `main` function is only responsible for calling `run` and handling any errors that come from
it. And our `run` function is responsible for initializing dependencies and starting our
application. This consolidates all our error handling to a single place, and it allows us to write
unit tests for the `run` function that assert proper outputs.

For more information on this pattern see this
excellent [blog post](https://grafana.com/blog/2024/02/09/how-i-write-http-services-in-go-after-13-years/)
by Matt Ryer.

### Connect to PostgreSQL

Next, we'll connect our application to our PostgreSQL server. We'll leverage the `run` function we
just created as the spot to load our variables and initialize this connection.

To initialize our connection we're going to use the `database/sql` package from the standard library and the `pgx/stdlib`
Postgres driver. For more advanced DB connection logic (such as leveraging retries, backoffs, and error
handling) you may want to create a separate database package.

First, in `cmd/api/main.go`, lets update `run`. Since connection to the database is just startup logic, we put it here instead of in its own package. Add the bellow code to the `run` function after to configuration and logger setup logic.:

```go
// Create a new DB connection using environment config
logger.DebugContext(ctx, "Connecting to database")
db, err := sql.Open("pgx", fmt.Sprintf(
    "host=%s user=%s password=%s dbname=%s port=%s sslmode=disable",
    cfg.DBHost,
    cfg.DBUserName,
    cfg.DBUserPassword,
    cfg.DBName,
    cfg.DBPort,
))
if err != nil {
    return fmt.Errorf("[in main.run] failed to open database: %w", err)
}

// Ping the database to verify connection
logger.DebugContext(ctx, "Pinging database")
if err = db.PingContext(ctx); err != nil {
    return fmt.Errorf("[in main.run] failed to ping database: %w", err)
}

defer func() {
    logger.DebugContext(ctx, "Closing database connection")
    if err = db.Close(); err != nil {
        logger.ErrorContext(ctx, "Failed to close database connection", "err", err)
    }
}()

logger.InfoContext(ctx, "Connected successfully to the database")

return nil                                                  
```

Then, add the following import to the existing import statement: 

```go
_ "github.com/jackc/pgx/v5/stdlib"
```

This will import the `pgx` driver to be used by the `database/sql` package. Note that we are not explicitly using the import, but are rather importing it for effect. Behind the scenes, an `init()` function is called in the `pgx` package when its imported that loaded the database driver so it can be used by the `database/sql` package.

At this point, you can now test to see if you application is able to successfully connect to the
Postgres database. To do so, open a terminal in the project root directory and run the bellow command. You should see logs indicating you connected to the database.

```bash
go run cmd/api/main.go
```

Congrats! You have managed to connect to your Postgres database from your application.

If your application is unable to connect to the database, ensure that the podman container for the
database is running. Additionally, verify that the environment variables set up in previous steps
are being loaded correctly.

### Setting up User Model

Now that we can connect to the database we'll set up our user domain model. This model is our
internal, domain specific representation of a User. Effectively it represents how a User is stored
in our database.

Create a `user.go` file in the `internal/models` package. Add the following struct:

```go
package models

type User struct {
    ID       uint
    Name     string
    Email    string
    Password string
}
```
Next, lets delete the `models.go` file in the models package as we wont be using this project.

### Creating our User Service

Next, we'll begin to build out the service layer in our application. Our service layer is where all
of our application logic (including database access) will live. It's important to remember that
there are many ways to structure Go applications. We're following a very basic layered architecture
that places most of our logic and dependencies in a services package. This allows our handlers to
focus on request and response logic, and gives us a single point to find application logic.

Start by adding the following struct, constructor function, and methods to the `internal/services/users.go` file. This file will hold the
definitions for our user service:

```go
// UsersService is a service capable of performing CRUD operations for
// models.User models.
type UsersService struct {
	logger *slog.Logger
	db     *sql.DB
}

// NewUsersService creates a new UsersService and returns a pointer to it.
func NewUsersService(logger *slog.Logger, db *sql.DB) *UsersService {
	return &UsersService{
		logger: logger,
		db:     db,
	}
}

// CreateUser attempts to create the provided user, returning a fully hydrated
// models.User or an error.
func (s *UsersService) CreateUser(ctx context.Context, user models.User) (models.User, error) {
    return models.User{}, nil
}

// ReadUser attempts to read a user from the database using the provided id. A
// fully hydrated models.User or error is returned.
func (s *UsersService) ReadUser(ctx context.Context, id uint64) (models.User, error) {
    return models.User{}, nil
}

// UpdateUser attempts to perform an update of the user with the provided id,
// updating, it to reflect the properties on the provided patch object. A
// models.User or an error.
func (s *UsersService) UpdateUser(ctx context.Context, id uint64, patch models.User) (models.User, error) {
    return models.User{}, nil
}

// DeleteUser attempts to delete the user with the provided id. An error is
// returned if the delete fails.
func (s *UsersService) DeleteUser(ctx context.Context, id uint64) error {
    return nil
}

// ListUsers attempts to list all users in the database. A slice of models.User
// or an error is returned.
func (s *UsersService) ListUsers(ctx context.Context, id uint64) ([]models.User, error) {
    return []models.User{}, nil
}
```

We've stubbed out a basic `UsersService` capable of performing CRUD on our User model. Next we'll
flesh out the `ReadUser` method.

Update the `ReadUser` method to below:

```go
func (s *UsersService) ReadUser(ctx context.Context, id uint64) (models.User, error) {
	s.logger.DebugContext(ctx, "Reading user", "id", id)

	row := s.db.QueryRowContext(
		ctx,
		`
		SELECT id,
		       name,
		       email,
		       password
		FROM users
		WHERE id = $1::int
        `,
		id,
	)

	var user models.User

	err := row.Scan(&user.ID, &user.Name, &user.Email, &user.Password)
	if err != nil {
		switch {
		case errors.Is(err, sql.ErrNoRows):
			return models.User{}, nil
		default:
			return models.User{}, fmt.Errorf(
				"[in services.UsersService.ReadUser] failed to read user: %w",
				err,
			)
		}
	}

	return user, nil
}
```

Let's quickly walk through the structure of this method, as it will serve as a template for other
similar methods:

- First we call the `QueryRowContext()` method of our db object which executes a query that is expected to return at most one row. In this case, the query returns an object based on `id`.
- Next we create a `user` variable to hold the information of the user we search for.
- Next we scan the contents of the returned row into the `user` variable we just defined.
    - Note that we pass a pointer to the `user` variable we declared so that the information can be
      bound to the object.
- Next we check if there was an error retrieving the information. If there was, we do the following: 
    - Check if the error is `sql.ErrNoRows`. If it is, we can return an empty `models.User` struct.
    - For all other errors, we wrap it using `fmt.Errorf` and return it. More information on error wrapping can be
  found [here](https://rollbar.com/blog/golang-wrap-and-unwrap-error/#).
- Finally if there was no error we return the `user`.

Now that you've implemented the `ReadUser` method, go through an implement the other CRUD methods.

These methods should leverage the `QueryContext`, `QueryRowContext`, and `ExecContext` methods on the `db` object on `UsersService`. It is possible that there are other ways of
implementing these methods and you should feel free to implement them as you see fit. 

If you get stuck, here are some helpful resources on working with `database/sql`:
- [Tutorial: Accessing a relational database](https://go.dev/doc/tutorial/database-access)
- [Go database/sql tutorial](http://go-database-sql.org/)
- [How to Work with SQL Databases in Go](https://betterstack.com/community/guides/scaling-go/sql-databases-in-go/)

## Server Setup

Now that we have a user service that can interact with the database layer, we can set up our http
server. Our server is comprised of two main components. Routes and handlers. Routes are a
combination of http method and path that we accept requests at. We'll start by defining a handler,
then we'll attach it to a route, and finally we'll attach those routes to a server so we can invoke
them.

### Handler setup

In Go, HTTP handlers are used to process HTTP requests. Our handlers will implement the
`http.Handler` interface from the `net/http` package in the standard library (making them standard
library compatible). This interface requires a `ServeHTTP(w http.ResponseWriter, r *http.Request)`
method. Handlers can be also be defined as functions using the `http.HandlerFunc` type which allows
a function with the correct signature to be used as a handler. We'll define our handlers using the
function form.

In the `internal/handlers` package create a new `read_user.go` file. Copy the stub implementation
from below:

```go
func HandleReadUser(logger *slog.Logger) http.Handler {
    return http.HandlerFunc(func (w http.ResponseWriter, r *http.Request) {
        // Set the status code to 200 OK
        w.WriteHeader(http.StatusOK)

        id := r.PathValue("id")
        if id == "" {
            http.Error(w, "not found", http.StatusNotFound)
            return
        }

        // Write the response body, simply echo the ID back out
        _, err := w.Write([]byte(id))
        if err != nil {
            // Handle error if response writing fails
            logger.ErrorContext(r.Context(), "failed to write response", slog.String("error", err.Error()))
            http.Error(w, "Internal Server Error", http.StatusInternalServerError)
        }
    })
}
```

Notice that we're not defining a handler directly, rather we've defined a function that returns a
handler. This allows us to pass dependencies into the outer function and access them in our handler.

### Route setup

Now that we've defined a handler we'll create a function in our `internal/routes` package that will
be used to attach routes to an HTTP server. This will give us a single point in the future to see
all our routes and their handlers at a glance

In the `internal/routes/routes.go` file we'll define the function below:

```go
func AddRoutes(mux *http.ServeMux, logger *slog.Logger, usersService *services.UsersService) {
    // Read a user
    mux.Handle("GET /api/users/{id}", handlers.HandleReadUser(logger))
}
```

### Adding a server to main.go

With our service and handler defined we can add our server in `main.go`

Modify the `run` function in `main.go` to include the following below the dependencies we've
initialized along with code to create and run our server along with graceful shutdown logic:

```go
// Create a new users service
usersService := services.NewUsersService(logger, db)

// Create a serve mux to act as our route multiplexer
mux := http.NewServeMux()

// Add our routes to the mux
routes.AddRoutes(mux, logger, usersService)

// Create a new http server with our mux as the handler
httpServer := &http.Server{
    Addr:    net.JoinHostPort(cfg.Host, cfg.Port),
    Handler: mux,
}

errChan := make(chan error)

// Server run context
ctx, done := context.WithCancel(ctx)
defer done()

// Handle graceful shutdown with go routine on SIGINT
go func() {
    // create a channel to listen for SIGINT and then block until it is received
    sig := make(chan os.Signal, 1)
    signal.Notify(sig, os.Interrupt)
    <-sig

    logger.DebugContext(ctx, "Received SIGINT, shutting down server")

    // Create a context with a timeout to allow the server to shut down gracefully
    ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

    // Shutdown the server. If an error occurs, send it to the error channel
    if err = httpServer.Shutdown(ctx); err != nil {
        errChan <- fmt.Errorf("[in main.run] failed to shutdown http server: %w", err)
        return
    }

    // Close the idle connections channel, unblocking `run()`
    done()
}()

// Start the http server
// 
// once httpServer.Shutdown is called, it will always return a
// http.ErrServerClosed error and we don't care about that error.
logger.InfoContext(ctx, "listening", slog.String("address", httpServer.Addr))
if err = httpServer.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
    return fmt.Errorf("[in main.run] failed to listen and serve: %w", err)
}

// block until the server is shut down or an error occurs
select {
case err = <-errChan:
    return err
case <-ctx.Done():
    return nil
}
```

Lets talk about whats going on here:
- First, we are initializing an instance of our `UserService` by passing the logger and database connection to it.
- next, we are creating a server mux, passing it to `AddRoutes()` to add routes, and then creating an instance of the `http.Server` struct that includes the address of our web server and our mux.
- After that, we are setting up graceful shutdown logic. We do this by: 
    - Starting a Go routine and the immediately blocking until we receive a cancellation signal across a channel. This lets us wait until the server is starting to shutdown before running any shutdown logic we need. 
    - After the signal is received, we create a cancellation context so that when we call `httpServer.Shutdown`, it can only run for a fixed amount of time. 
    - After all the shutdown logic has run, we call `done()` which will unblock our `run()` function and let us finally exit.
- Next, we start our server by calling httpServer.ListenAndServe() and checking any errors that are returned.
- Lastly, we use a `select` statement to block until the server has successfully shut down, or an error is sent across the `errChan` channel from our graceful shutdown Go routine.


If we run the application we should now see logs indicating our server is running including the
address. Try hitting our user endpoint! You can do this by using a tool like [postman](https://www.postman.com/), a VSCode extension like [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client), or using `CURL` from the command line with the following command: 

```bash
curl -X GET localhost:8000/api/users/1
```
> Note, we are passing the ID of a user as the last value in the path. Try changing this value and see what happens!

Now try closing the application with `ctrl + C`. You should see some log messages in the terminal telling you that your graceful shutdown logic is running!

## Add Middleware

### Example: Adding a Logger Middleware

We often will need to modify or inspect requests and responses before or after they are handled by our handlers. Middleware is a way to do this. Middleware is a function that wraps an `http.Handler` and can modify the request or response before or after the handler is called. 

First, in `internal/middleware/middleware.go`, add the following line:

```go
// Middleware is a function that wraps an http.Handler.
type Middleware func(next http.Handler) http.Handler
```

This defines a custom type `Middleware` that is a function that takes an `http.Handler` and returns an `http.Handler`. This will allow us to define middleware that can wrap our handlers and modify the request or response before or after the handler is called.

Next, create the file `internal/middleware/logger.go` and add the following code:

```go
type wrappedWriter struct {
	http.ResponseWriter
	statusCode int
}

func (w *wrappedWriter) WriteHeader(statusCode int) {
	w.ResponseWriter.WriteHeader(statusCode)
	w.statusCode = statusCode
}

// Logger is a middleware that logs the request method, path, duration, and
// status code.
func Logger(logger *slog.Logger) Middleware {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()

			wrapped := &wrappedWriter{
				ResponseWriter: w,
				statusCode:     http.StatusOK,
			}

			next.ServeHTTP(wrapped, r)

			logger.InfoContext(
				r.Context(),
				"request completed",
				slog.String("method", r.Method),
				slog.String("path", r.URL.Path),
				slog.String("duration", time.Since(start).String()),
				slog.Int("status", wrapped.statusCode),
			)
		})
	}
}
````

There is a lot going on here, so lets break it down:
- We define a new type `wrappedWriter` that embeds an `http.ResponseWriter` and adds a `statusCode` field. This will allow us to track the status code of the response.
- We define a WriteHeader method on `wrappedWriter` that sets the `statusCode` field. This method overrides the method of the same name on the `http.ResponseWriter` interface. When a handler calls `WriteHeader` to set the status code of the response, it will actually call this method instead. We can use this to access the status code of the response.
- We define a `Logger` function that returns a `Middleware` function using a closure. This function takes a logger and returns a middleware function that logs the request method, path, duration, and status code of the response. We do this by wrapping the `http.Handler` that is passed to the middleware function and calling the `ServeHTTP` method on the wrapped handler. This allows us to run code before and after the handler is called. After the handler is called, we log the request method, path, duration, and status code of the response.

Next, in `cmd/api/main.go`, add the following code to the `run` function between the call to `routes.AddRoutes` and the definition of `httpServer` to add the logger middleware to the mux:

```go
// Wrap the mux with middleware
wrappedMux := middleware.Logger(logger)(mux)
```
Finally, update the `httpServer` definition to use the `wrappedMux` instead of the `mux`:

```go
// Create a new http server with our mux as the handler
httpServer := &http.Server{
    Addr:    net.JoinHostPort(cfg.Host, cfg.Port),
    Handler: wrappedMux,
}
```

If you run the application now and make a request to the existing endpoint, you should see logs indicating that the request method, path, duration, and status code are being logged. Try hitting the user endpoint again and see the logs that are generated!

### Assignment: Add recovery middleware

Now that you have seen how to create middleware in Go, try adding a recovery middleware to the application. Recovery middleware is used to recover from panics that occur in the application. Panics are a way to handle unrecoverable errors in Go, and can be used to recover from them and return a 500 status code to the client. Bellow are the criteria for the recovery middleware:
- The middleware should recover from panics that occur in the handlers or anything the handlers call.
- The middleware should log the error that caused the panic.
- The middleware should return a 500 status code to the client if a panic occurs.
- The Middleware should be called from `main.go` after the logger middleware is added.

Here are some resources you can use to learn more about panics and recovery in Go:
- [Go By Example: Recovery](https://gobyexample.com/recover)
- [Defer, Panic, and Recover](https://blog.golang.org/defer-panic-and-recover)

## Generating Swagger Docs

To add swagger to our application, we will need to provide swagger basic information to help generate our swagger documentation.
In `internal/routes/routes.go` add the following comments above the `AddRoutes` function:

```
// @title						Blog Service API
// @version						1.0
// @description					Practice Go API using the Standard Library and Postgres
// @termsOfService				http://swagger.io/terms/
// @contact.name				API Support
// @contact.url					http://www.swagger.io/support
// @contact.email				support@swagger.io
// @license.name				Apache 2.0
// @license.url					http://www.apache.org/licenses/LICENSE-2.0.html
// @host						localhost:8000
// @BasePath					/api
// @externalDocs.description    OpenAPI
// @externalDocs.url			https://swagger.io/resources/open-api/
```

For more detailed description on what each annotation does, please
see [Swaggo's Declarative Comments Format](https://github.com/swaggo/swag?tab=readme-ov-file#declarative-comments-format)

Next, we will add swagger comments for our handler. In `internal/handlers/read_user.go` add the
following comments above the `HandleReadUser` function:

```
// @Summary		Read User
// @Description	Read User by ID
// @Tags		user
// @Accept		json
// @Produce		json
// @Param		id           path	    string	    true	"User ID"
// @Success		200	         {object}	uint
// @Failure		400	         {object}	string
// @Failure		404	         {object}	string
// @Failure		500	         {object}	string
// @Router		/users/{id}  [GET]
```

The above comments give swagger important information such as the path of the endpoint, requst
parameters, request bodies, and response types. For more information about each annotation and
additional annotations you will need,
see [Swaggo Api Operation](https://github.com/swaggo/swag?tab=readme-ov-file#api-operation).

Almost there! We can now attach swagger to our project and generate the documentation based off our
comments. In the `internal/routes/routes.go`, update the `AddRoutes` function to match:

```go
func AddRoutes(mux *http.ServeMux, logger *slog.Logger, usersService *services.UsersService, baseURL string) {
	// Read a user
	mux.Handle("GET /api/users/{id}", handlers.HandleReadUser(logger))

	// swagger docs
	mux.Handle(
		"GET /swagger/",
		httpSwagger.Handler(httpSwagger.URL(baseURL+"/swagger/doc.json")),
	)
	logger.Info("Swagger running", slog.String("url", baseURL+"/swagger/index.html"))
}
```

We have now added a new handler that will show us our swagger docs in the browser.

Next, lets update our call to `AddRoutes()` in `main.run()` to include the base URL. It should now look like this:

```go
// Add our routes to the mux
routes.AddRoutes(
    mux,
    logger,
    usersService,
    fmt.Sprintf("http://%s:%s", cfg.Host, cfg.Port),
)
```

Next, generate the swagger documentation by running the following make command:

```bash
make swag-init
```

If successful, this should generate the swagger documentation for the project and place it in
`cmd/api/docs`.

Finally, go back to `internal/routes/routes.go` and add the following to your list of imports. Remember
to replace `[name]` with your name:

```
_ "github.com/[name]/blog/cmd/api/docs"
```

Congrats! You have now generated the swagger documentation for our application! We can now start up
our application and hit our endpoints!

We now have enough code to run the API end-to-end!

At this point, you should be able to run your application. You can do this using the make command
`make start-web-app` or using basic go build and run commands. If you encounter issues, ensure that
your database container is running in with colima, and that there are no syntax errors present in the
code.

Run the application and navigate to the swagger endpoint to see your collection of routes. You can do this by going to the following URL in a web browser: http://localhost:8000/swagger/index.html. Try
interacting with the read user route to verify it returns a response with our path parameter. Next,
we'll finish fleshing out that handler and create the rest of our handlers and routes.

## Injecting the user service into the read user handler

Now that we've verified our handler is properly handling http requests we'll implement some actual
read user logic. To do this, we need to make our user service accessible to the handler. We already
defined our handler as a closure, giving us a place to inject dependencies.

Instead of injecting the service directly we're going to leverage a features of Go and define and
inject a small interface.

In Go, interfaces are implemented implicitly. Which makes them a fantastic tool to abstract away the
details of a service at the point its used. Let's define the interface to see what we mean.

In `internal/handlers/read_user.go` add the following interface definition to the top of the file:

```go
// userReader represents a type capable of reading a user from storage and
// returning it or an error.
type userReader interface {
    ReadUser(ctx context.Context, id uint64) (models.User, error)
}
```

The Go community encourages this style of interface declaration. The interface is defined at the
point it's consumed, which allows us to narrow down the methods to only the single `ReadUser` method
we need. This greatly simplifies testing by simplifying the mock we need to create. This also gives
us additional type safety in that we've guaranteed that the handler for reading a user doesn't have
access to other functionality like deleting a user.

Now that we've defined our interface we can inject it. Add an argument for the interface to the
`HandleReadUser` function:

```go
func HandleReadUser(logger *slog.Logger, userReader userReader) http.Handler {
    // ... handler functionality
}
```

And update our handler invocation in the `internal/routes/routes.go` `AddRoutes` function:

```go
mux.Handle("GET /api/users/{id}", handlers.HandleReadUser(logger, usersService))
```

Notice that our user service can be supplied to `HandleReadUser` as it satisfies the `userReader`
interface. This style of accepting interfaces at implementation, and returning structs from
declaration is extremely popular in Go.

## Hiding the read user response type

A general best practice with developing API's is to define request and response models separate from
our domain models. This means a little bit of extra mapping, but keeps our domain model from leaking
out of our API. This also gives us some flexibility in the event a request or response doesn't
cleanly map to a domain model.

Update `internal/handlers/read_user.go` to have the following type defintion:

```go
// readUserResponse represents the response for reading a user.
type readUserResponse struct {
    ID       uint   `json:"id"`
    Name     string `json:"name"`
    Email    string `json:"email"`
    Password string `json:"password"`
}
```

## Reading the user and mapping it to a response

With our response type defined and our user service injected it's time to read our user model and
map it into a response. Update the `http.HandlerFunc` returned from `HandleReadUser` to the
following:

```go
func HandleReadUser(logger *slog.Logger, userReader userReader) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		// Read id from path parameters
		idStr := r.PathValue("id")

		// Convert the ID from string to int
		id, err := strconv.Atoi(idStr)
		if err != nil {
			logger.ErrorContext(
				r.Context(),
				"failed to parse id from url",
				slog.String("id", idStr),
				slog.String("error", err.Error()),
			)

			http.Error(w, "Invalid ID", http.StatusBadRequest)
			return
		}

		// Read the user
		user, err := userReader.ReadUser(ctx, uint64(id))
		if err != nil {
			logger.ErrorContext(
				r.Context(),
				"failed to read user",
				slog.String("error", err.Error()),
			)

			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			return
		}

		// Convert our models.User domain model into a response model.
		response := readUserResponse{
			ID:       user.ID,
			Name:     user.Name,
			Email:    user.Email,
			Password: user.Password,
		}

		// Encode the response model as JSON
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(w).Encode(response); err != nil {
			logger.ErrorContext(
				r.Context(),
				"failed to encode response",
				slog.String("error", err.Error()))

			http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		}
	})
}
```
Now that we have defined what our response model is, we can update our swagger documentation to reflect this. Update the `@Success` annotation in `internal/handlers/read_user.go` to the following:

```go
//	@Success		200	{object}	readUserResponse
```

At this point we can rerun `make swag-init` and restart the server process and hit our read user endpoint again from swagger.

## Flesh out user CRUD routes / handlers

Now that we've fully fleshed out the read user endpoint we can create routes and handlers for each
of our other user CRUD operations.

| Operation   | Method   | Path              | Handler File     | Handler            |
|-------------|----------|-------------------|------------------|--------------------|
| Create User | `POST`   | `/api/users`      | `create_user.go` | `HandleCreateUser` |
| Update User | `PUT`    | `/api/users/{id}` | `update_user.go` | `HandleUpdateUser` |
| Delete User | `DELETE` | `/api/users/{id}` | `delete_user.go` | `HandleDeleteUser` |
| List Users  | `GET`    | `/api/users`      | `list_users.go`  | `HandleListUsers`  |

Remember to add the appropriate swagger annotations to each handler!

## Input model validation

One thing we still need is validation for incoming requests. We can create another single method
interface to help with this. Create a new `handlers.go` file in the `internal/handlers` package.
This will serve as a spot for shared handler types and logic.

Add the following interface and function to the file:

```go
package handlers

// validator is an object that can be validated.
type validator interface {
    // Valid checks the object and returns any
    // problems. If len(problems) == 0 then
    // the object is valid.
    Valid(ctx context.Context) (problems map[string]string)
}

// decodeValid decodes a model from an http request and performs validation
// on it.
func decodeValid[T validator](r *http.Request) (T, map[string]string, error) {
    var v T
    if err := json.NewDecoder(r.Body).Decode(&v); err != nil {
        return v, nil, fmt.Errorf("decode json: %w", err)
    }
    if problems := v.Valid(r.Context()); len(problems) > 0 {
        return v, problems, fmt.Errorf("invalid %T: %d problems", v, len(problems))
    }
    return v, nil, nil
}
```

While writing handlers for requests that have input models we can use the code above to decode
models from the request body. Notice that `decodeValid` takes a generic that must implement the
`validator` interface. To call the function ensure the model you're attempting to decode implements
`validator`.

## Unit Testing

### Unit Testing Introduction

It is important with any language to test your code. Go make it easy to write unit tests, with a
robust built-in testing framework. For a brief introduction on unit testing in Go, check
out [this YouTube video](https://www.youtube.com/watch?v=FjkSJ1iXKpg).

### Unit Testing in This Tech Challenge

Unit testing is a required part of this tech challenge. There are not specific requirements for
exactly how you must write your unit tests, but keep the following in mind as you go through the
challenge:

- Go prefers to use table-driven, parallel unit tests. For more information on this, check out
  the [Go Wiki](https://go.dev/wiki/TableDrivenTests).
- Try to write your code in a way that is, among other things, easy to test. Go's preference for
  interfaces facilitates this nicely, and it can make your life easier when writing tests.
- There are already make targets set up to run unit tests. Specifically `check-coverage`. Feel free
  to modify these and add more if you would like to tailor them to your own preferences.

### Example: Handler unit test

Even though there are no requirements on how you write your tests, here is an example of a very basic unit test for a simple handler.

First, lets create a new handler. For this we are going to create a health check endpoint. To do this, create the file `internal/handlers/health.go` and add the following code:

```go
// healthResponse represents the response for the health check.
type healthResponse struct {
	Status string `json:"status"`
}

// HandleHealthCheck handles the health check endpoint
//
//	@Summary		Health Check
//	@Description	Health Check endpoint
//	@Tags			health
//	@Accept			json
//	@Produce		json
//	@Success		200		{object}	healthResponse
//	@Router			/health	[GET]
func HandleHealthCheck(logger *slog.Logger) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        logger.InfoContext(r.Context(), "health check called")
        
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        _ = json.NewEncoder(w).Encode(healthResponse{Status: "ok"})
    }
}
```

Next, lets register this handler with a route in side of the `internal/routes/routes.go` file by adding the following code to `AddRoutes()`:

```go
// health check
mux.Handle("GET /api/health", handlers.HandleHealthCheck(logger))
```

If you start the application and navigate to `http://localhost:8000/api/health` you should see a response with a status of `ok`.

Next, lets write a unit test for this handler. Create a new file `internal/handlers/health_test.go` and add the following unit test:

```go
func TestHandleHealthCheck(t *testing.T) {
    tests := map[string]struct {
        wantStatus int
        wantBody   string
    }{
        "happy path": {
            wantStatus: 200,
            wantBody:   `{"status":"ok"}`,
        },
    }
    for name, tc := range tests {
        t.Run(name, func(t *testing.T) {
            // Create a new request
            req := httptest.NewRequest("GET", "/health", nil)

            // Create a new response recorder
            rec := httptest.NewRecorder()

            // Create a new logger
            logger := slog.Default()

            // Call the handler
            HandleHealthCheck(logger)(rec, req)

            // Check the status code
            if rec.Code != tc.wantStatus {
                t.Errorf("want status %d, got %d", tc.wantStatus, rec.Code)
            }

            // Check the body
            if strings.Trim(rec.Body.String(), "\n") != tc.wantBody {
                t.Errorf("want body %q, got %q", tc.wantBody, rec.Body.String())
            }
        })
    }
}
```

Lets break down what is happening in this test:
- We are creating a map of test cases. Each test case has a name, and a struct with the expected status code and body.
- We are then iterating over each test case and running a sub-test for each one.
- In each sub-test we are creating a new request, response recorder, and logger.
- We then call the handler with the logger and response recorder.
- Finally, we check the status code and body of the response recorder to ensure they match the expected values.

### Example: Service unit test

Now that we have looked at writting a unit test for a handler, lets look at writting a unit test for a service. For this example, we are going to write a unit test for the `ReadUser` method in the `UsersService` struct. This test will be a little more complex than the handler test, as we will need to mock the database connection. To do this, we will use the `github.com/DATA-DOG/go-sqlmock` package. 

Lets create our test! Create a new file `internal/services/users_test.go` and add the following code:

```go
func TestUsersService_ReadUser(t *testing.T) {
    testcases := map[string]struct {
        mockCalled     bool
        mockInputArgs  []driver.Value
        mockOutput     *sqlmock.Rows
        mockError      error
        input          uint64
        expectedOutput models.User
        expectedError  error
    }{
        "happy path": {
            mockCalled:    true,
            mockInputArgs: []driver.Value{1},
            mockOutput: sqlmock.NewRows([]string{"id", "name", "email", "password"}).
                AddRow(1, "john", "john@me.com", "password123!"),
            mockError: nil,
            input:     1,
            expectedOutput: models.User{
                ID:       1,
                Name:     "john",
                Email:    "john@me.com",
                Password: "password123!",
            },
            expectedError: nil,
        },
    }
    for name, tc := range testcases {
        t.Run(name, func(t *testing.T) {
            db, mock, err := sqlmock.New()
            if err != nil {
                t.Fatalf("an error '%s' was not expected when opening a stub database connection", err)
            }
            defer db.Close()

            logger := slog.Default()
			
            if tc.mockCalled {
                mock.
                    ExpectQuery(regexp.QuoteMeta(`
                        SELECT id,
                               name,
                               email,
                               password
                        FROM users
                        WHERE id = $1::int
                    `)).
                    WithArgs(tc.mockInputArgs...).
                    WillReturnRows(tc.mockOutput).
                    WillReturnError(tc.mockError)
            }

            userService := NewUsersService(logger, db)

            output, err := userService.ReadUser(context.TODO(), tc.input)
            if err != tc.expectedError {
                t.Errorf("expected no error, got %v", err)
            }
            if output != tc.expectedOutput {
                t.Errorf("expected %v, got %v", tc.expectedOutput, output)
            }

            if tc.mockCalled {
                if err = mock.ExpectationsWereMet(); err != nil {
                    t.Errorf("there were unfulfilled expectations: %s", err)
                }
            }
        })
    }
}
```

There is a lot going on here, so lets break it down!
- When we create our test case struct, we define some fields that will control our mock and its behavior. These fields include: 
  - `mockCalled`, to determine if the mock should be called
  - `mockInputArgs`, to define the input arguments to the mock
  - `mockOutput`, to define the output of the mock, 
  - `mockError`, to define the error the mock should return
- Inside of the test body, we create a new mock database connection and defer its closure. We can use the `mock` to define the expected behavior of the database query and tell the mocked database what to return.
- We then use the test case values to determine if the mock should be called, and if it should, we define the expected behavior of the mock.
  - Note the use of `regexp.QuoteMeta` to escape the query string. This is important to ensure that the query string is matched correctly by `sqlmock`. 
- We then create a new instance of the `UsersService` and call the `ReadUser` method with the mocked database connection.
- Finally, we check the output and error of the method to ensure they match the expected values.

Now that we have defined a basic test for the happy path, try adding other test cases to the test to test other scenarios? What if the database query fails? What if the user does not exist? 

The testing patterns shown here should be enough for you to be able to fully test the rest of the application. With that being said, here are a couple of other resources you might find helpful:
- [testify](https://github.com/stretchr/testify): A popular testing library that provides a lot of helpful utilities for writing tests such as assertions and mocks.
- [mockery](https://vektra.github.io/mockery/latest/): A tool for generating mocks for interfaces and builds on `testify`.
- [Go Wiki: TableDrivenTests](https://go.dev/wiki/TableDrivenTests): A great resource for learning about table-driven tests in Go.

## Next Steps

You are now ready to move on to the rest of the challenge. You can find the instructions for
that [here](./3-Challenge-Assignment.md).

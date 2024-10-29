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
- [Generating Swagger Docs](#generating-swagger-docs)
- [Injecting the user service into the read user handler](#injecting-the-user-service-into-the-read-user-handler)
- [Hiding the read user response type](#hiding-the-read-user-response-type)
- [Reading the user and mapping it to a response](#reading-the-user-and-mapping-it-to-a-response)
- [Flesh out user CRUD routes / handlers](#flesh-out-user-crud-routes--handlers)
- [Input model validation](#input-model-validation)
- [Unit Testing](#unit-testing)
    - [Unit Testing Introduction](#unit-testing-introduction)
    - [Unit Testing in This Tech Challenge](#unit-testing-in-this-tech-challenge)
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
│   ├── server
│   │   └── server.go
│   ├── models
│   │   └── models.go
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
configuration.

First, create a `.env` file at the root of the project to contain environment variables, including
the credentials required for the Postgres image.

First, update the `.env` file with the following environment variables:

```
CLIENT_ORIGIN=http://localhost:3000
HOST=127.0.0.1
PORT=8000
```

### Load and Validate Environment Variables

To handle loading environment variables into the application, we will utilize the [
`env`](https://github.com/caarlos0/env) package from `caarlos0` as well as the [
`godotenv`](https://github.com/joho/godotenv) package.

If you have not already done so, download these packages by running the following command in your
terminal:

```sh
go get github.com/caarlos0/env/v11 github.com/joho/godotenv
```

`env` is used to parse values from our system environment variables and map them to properties on a
struct we've defined. `env` can also be used to perform validation on environment variables such as
ensuring they are defined and don't contain an empty value.

`godotenv` is used to load values from `.env` files into system environment variables. This allows
us to define these values in a `.env` file for local development.

Now, find the `internal/config/config.go` file. This is where we'll define the struct to contain our
environment variables.

Add the struct definition below to the file:

```go
package config

// Config holds the application configuration settings. The configuration is loaded from
// environment variables.
type Config struct {
    DBHost         string `env:"DATABASE_HOST,required"`
    DBUserName     string `env:"DATABASE_USER,required"`
    DBUserPassword string `env:"DATABASE_PASSWORD,required"`
    DBName         string `env:"DATABASE_NAME,required"`
    DBPort         string `env:"DATABASE_PORT,required"`
    ServerPort     string `env:"PORT,required"`
    ClientOrigin   string `env:"CLIENT_ORIGIN,required"`
    Host           string `env:"HOST,required"`
    Port           string `env:"PORT,required"`
}
```

Now, add the following function to the file:

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

### Creating a `run` function to initialize dependencies

Now that we can load config, let's take a step back and make an update to our `cmd/api/main.go`
file. One quirk of Go is that our `func main` can't return anything. Wouldn't it be nice if we could
return an error or a status code from `main` to signal that a dependency failed to initialize? We're
going to steal a pattern popularized by Matt Ryer to do exactly that.

First, in `cmd/api/main.go` we're going to add the function below:

```go
func run(ctx context.Context, w io.Writer) error {
    ctx, cancel := signal.NotifyContext(ctx, os.Interrupt)
    defer cancel()
    // We'll initialize dependencies here as we go...

    return nil
}
```

Next, we'll update `func main` to look like this:

```go
func main() {
    ctx := context.Background()
    if err := run(ctx, os.Stdout); err != nil {
        fmt.Fprintf(os.Stderr, "%s\n", err)
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

To initialize our connection we're going to use the `gorm` package and it's underlying `postgres`
driver. For more advanced DB connection logic (such as leveraging retries, backoffs, and error
handling) you may want to create a separate database package.

First, download the `gorm` package:

```sh
go get -u gorm.io/gorm gorm.io/driver/postgres
```

Then, in `internal/database/database.go`, lets add a new function called `Connect`. This function will be responsible for connection to our database. Add the following code:

```go

func Connect(ctx context.Context, logger *slog.Logger, cfg Config) (*gorm.DB, error) {
    // Create a new DB connection using environment config
    logger.DebugContext(ctx, "Connecting to database")
    db, err := gorm.Open(
        postgres.Open(
            fmt.Sprintf(
                "host=%s user=%s password=%s dbname=%s port=%s sslmode=disable TimeZone=UTC",
                cfg.DBHost,
                cfg.DBUserName,
                cfg.DBUserPassword,
                cfg.DBName,
                cfg.DBPort,
            ),
        ),
        &gorm.Config{},
    )
    if err != nil {
        return fmt.Errorf("[in database.Connect] failed to open database: %w", err)
    }

    logger.DebugContext(ctx, "Successfully connected to database")

    return db, nil
}

```

Now, back in the `cmd/api/main.go` file, update `run` to contain the snippet below. This code will go right after `defer cancel()` inside of the `run` function. You will need to import the new database package we just added the `Connect` function too:

```go
// ... other code from run

// Load and validate environment config
cfg, err := config.New()
if err != nil {
    return fmt.Errorf("[in main.run] failed to load config: %w", err)
}

// Create a structured logger, which will print logs in json format to the
// writer we specify.
logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

// Create a new DB connection using environment config
db, err := database.Connect(ctx, logger, cfg)
if err != nil {
    return fmt.Errorf("[in main.run] failed to open database: %w", err)
}

logger.Info("Connected successfully to the database")

// ... other code from run
```

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
    db     *gorm.DB
}

// NewUsersService creates a new UsersService and returns a pointer to it.
func NewUsersService(logger *slog.Logger, db *gorm.DB) *UsersService {
    return &UsersService{
        logger: logger,
        db:     db,
    }
}

// CreateUser attempts to create the provided user, returning a fully hydrated
// models.User or an error.
func (s *UsersService) CreateUser(user models.User) (models.User, error) {
    return models.User{}, nil
}

// ReadUser attempts to read a user from the database using the provided id. A
// fully hydrated models.User or error is returned.
func (s *UsersService) ReadUser(id uint64) (models.User, error) {
    return models.User{}, nil
}

// UpdateUser attempts to perform an update of the user with the provided id,
// updating, it to reflect the properties on the provided patch object. A
// models.User or an error.
func (s *UsersService) UpdateUser(id uint64, patch models.User) (models.User, error) {
    return models.User{}, nil
}

// CreateUser attempts to create the provided user, returning a fully hydrated
// models.User or an error.
func (s *UsersService) DeleteUser(id uint64) error {
    return nil
}

// CreateUser attempts to create the provided user, returning a fully hydrated
// models.User or an error.
func (s *UsersService) ListUsers(id uint64) ([]models.User, error) {
    return []models.User{}, nil
}
```

We've stubbed out a basic `UsersService` capable of performing CRUD on our User model. Next we'll
flesh out the `ReadUser` method.

Update the `ReadUser` method to below:

```go
func (s *UsersService) ReadUser(id uint64) (models.User, error) {
    var user models.User

    if err := s.db.First(&user, id).Error; err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return user, nil
        }
        return user, fmt.Errorf("[in services.UsersService.ReadUser] failed to read user: %w", err)
    }

    return user, nil
}
```

Let's quickly walk through the structure of this method, as it will serve as a template for other
similar methods:

- First we create a `user` variable to hold the information of the user we search for.
- Next we use the `First` method on our database connection to load the first record with a matching
  ID. For documentation on this and other similar methods, see the Gorm
  docs [here](https://gorm.io/docs/query.html).
    - Note that we pass a pointer to the `user` variable we declared so that the information can be
      bound to the object.
- Next we check if there was an error retrieving the information. If an error is present we wrap it
  using `fmt.Errorf` and return it. More information on error wrapping can be
  found [here](https://rollbar.com/blog/golang-wrap-and-unwrap-error/#).
- Finally if there was no error we return the `user`.

Now that you've implemented the `ReadUser` method, go through an implement the other CRUD methods.

These methods should leverage the `Where`, `First`, `Create`, `Model`, `Updates`, and `Delete`
methods on the `db` object on `UsersService`. It is possible that there are other ways of
implementing these methods and you should feel free to implement them as you see fit.

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
func AddRoutes(mux *http.ServeMux, logger *slog.Logger, config config.Config, usersService *services.UsersService) {
    // Read a user
    mux.Handle("GET /api/users/{id}", handlers.HandleReadUser(logger))
}
```

### Server setup

Now that we've configured our handlers and routes we'll create an instance of an `http.Server` to
serve them.

In the `internal/server/server.go` file we'll define the function below:

```go
func NewServer(logger *slog.Logger, config config.Config, usersService *services.UsersService) http.Handler {
    // Create a serve mux to act as our route multiplexer
    mux := http.NewServeMux()
    // Add our routes to the mux
    routes.AddRoutes(
        mux,
        logger,
        config,
        usersService,
    )

    // Optionally configure middleware on the mux
    var handler http.Handler = mux
    // handler = someMiddleware(handler)
    // handler = someMiddleware2(handler)
    // handler = someMiddleware3(handler)
    return handler
}
```

### Adding a server to main.go

With our server constructor defined we can add our server to `main.go`

Modify the `run` function in `main.go` to include the following below the dependencies we've
initalized:

```go
usersService := services.NewUsersService(logger, db)
svr := server.NewServer(logger, cfg, usersService)
httpServer := &http.Server{
    Addr:    net.JoinHostPort(cfg.Host, cfg.Port),
    Handler: svr,
}

go func () {
    logger.InfoContext(ctx, "listening", slog.String("address", httpServer.Addr))
    if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
        fmt.Fprintf(os.Stderr, "error listening and serving: %s\n", err)
    }
}()
var wg sync.WaitGroup
wg.Add(1)
go func () {
    defer wg.Done()
    <-ctx.Done()
    shutdownCtx := context.Background()
    shutdownCtx, cancel := context.WithTimeout(shutdownCtx, 10 * time.Second)
    defer cancel()
    if err := httpServer.Shutdown(shutdownCtx); err != nil {
        fmt.Fprintf(os.Stderr, "error shutting down http server: %s\n", err)
    }
}()
wg.Wait()
return nil
```

This code initializes our `services.UsersService` and an instance of our server with routes and
middlware. This instance will act as the root handler for our `http.Server`. Finally we create a
pointer for an `http.Server`, attach our root handler to it, and start the server in a goroutine.

We include some cleanup logic in a seperate goroutine that will be run when the application exits.

If we run the application we should now see logs indicating our server is running including the
address. Try hitting our user endpoint! You can do this by using a tool like [postman](https://www.postman.com/), a VSCode extension like [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client), or using `CURL` from the command line with the following command: 

```bash
curl localhost:8000/api/users/1
```

> Note, we are passing the ID of a user as the last value in the path. Try changing this value and see what happens!

## Generating Swagger Docs

To add swagger to our application, ensure that you have already installed swaggo to the project
using the command below in your terminal:

```sh
go install github.com/swaggo/swag/cmd/swag@latest
```

Next, we will need to provide swagger basic information to help generate our swagger documentation.
In `internal/routes/routes.go` add the following comments above the `AddRoutes` function:

```
// @title						Blog Service API
// @version						1.0
// @description					Practice Go Gin API using GORM and Postgres
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
comments. In the `internal/routes/routes.go` we'll add a line to the `AddRoutes` function:

```go
mux.Handle(
    "GET /swagger/*", 
    httpSwagger.Handler(httpSwagger.URL(net.JoinHostPort(config.Host, config.Port)+"/swagger/doc.json")),
)
```

Next, generate the swagger documentation by running the following make command:

```bash
make swag-init
```

If successful, this should generate the swagger documentation for the project and place it in
`cmd/api/docs`.

> **Important:** The documentation that was just created may contain an error at the end of the file
> which will need to be handled before starting the application. To fix this, proceed over to the
> newly generated `cmd/api/docs/docs.go` file and remove the following two lines at the end of the
> project:
>
> ```
> LeftDelim:        "{{",
> RightDelim:       "}}",
> ```
>
> This issue appears to occur every time you generate the swagger documentation, and will be
> something to note as you continue working through the tech challenge
> Finally, proceed over to `cmd/api/main.go` and add the following to your list of imports. Remember
> to replace `[name]` with your name:

```
_ "github.com/[name]/blog/cmd/api/docs"
```

Congrats! You have now generated the swagger documentation for our application! We can now start up
our application and hit our endpoints!

We now have enough code to run the API end-to-end!

At this point, you should be able to run your application. You can do this using the make command
`make start-web-app` or using basic go build and run commands. If you encounter issues, ensure that
your database container is running in podman, and that there are no syntax errors present in the
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
    ReadUser(id uint64) (models.User, error)
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
return http.HandlerFunc(func (w http.ResponseWriter, r *http.Request) {
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
	user, err := userReader.ReadUser(uint64(id))
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
```

At this point we can restart the server process and hit our read user endpoint again from swagger.

## Flesh out user CRUD routes / handlers

Now that we've fully fleshed out the read user endpoint we can create routes and handlers for each
of our other user CRUD operations.

| Operation   | Method   | Path              | Handler File     | Handler            |
|-------------|----------|-------------------|------------------|--------------------|
| Create User | `POST`   | `/api/users`      | `create_user.go` | `HandleCreateUser` |
| Update User | `PUT`    | `/api/users/{id}` | `update_user.go` | `HandleUpdateUser` |
| Delete User | `DELETE` | `/api/users/{id}` | `delete_user.go` | `HandleDeleteUser` |
| List Users  | `GET`    | `/api/users`      | `list_users.go`  | `HandleListUsers`  |

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

## Next Steps

You are now ready to move on to the rest of the challenge. You can find the instructions for
that [here](./3-Challenge-Assignment.md).

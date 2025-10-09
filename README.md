FAA Route Finder
This project provides a backend service written in Zig to process and serve FAA (Federal Aviation Administration) flight route data, specifically Preferred Routes and Coded Departure Routes (CDRs). It downloads data directly from FAA CSV files, stores it in a MariaDB database, and exposes a simple API for querying available routes between two airports.

Features
Route Data Consolidation: Pulls data from both the NFDC Preferred Routes database and the CDM Operational CDRs database into a single, queryable source.

Simple API: Exposes a clean JSON API to find routes between an origin and destination.

Performant Backend: Written in Zig using the standard library's std.http.Server for a lightweight and fast foundation.

Modern Frontend: A clean, responsive user interface built with HTML and Tailwind CSS.

Tech Stack
Backend: Zig (v0.15.1)

Database: MariaDB

Web Server (Reverse Proxy): Apache (httpd)

Frontend: HTML, Tailwind CSS, JavaScript

Project Structure
src/main.zig: The main entry point for the Zig backend application.

build.zig: The Zig build script.

build.zig.zon: The Zig package manifest.

frontend/: Contains all frontend assets (HTML, CSS, JS).

.env: Configuration file for database credentials and server settings (not checked into git).

API Endpoints
Health Check
Endpoint: GET /api/health

Description: A simple endpoint to verify that the backend service is running.

Success Response:

Code: 200 OK

Content: {"status":"ok"}

(More endpoints like POST /api/routes/find will be documented here as they are built.)

Getting Started (on the Server)
Prerequisites: Zig 0.15.1, MariaDB, and Apache (httpd) must be installed.

Clone the Repository: git clone https://github.com/gewnthar/route.git /var/www/routes

Configuration: Create a .env file in the project root with the necessary database credentials and server port.

Build: Navigate to the project directory and run zig build -Doptimize=ReleaseFast.

Run: The application is managed by a systemd service (routes_app.service) which runs the compiled binary from zig-out/bin/routes_app.
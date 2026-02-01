# 🚀 Job Portal Web Application (MERN + Docker)

A full-stack **Job Portal Web Application** built using the **MERN stack**. This platform streamlines the recruitment process by enabling employers to manage job postings and applicants, while providing job seekers with a seamless interface to browse and apply for opportunities.

The entire application is **fully containerized using Docker**, ensuring environment consistency and production-ready architecture.

---

## 📌 Project Overview

This project demonstrates a scalable web application with role-based workflows. It emphasizes a clean separation of concerns between the frontend, backend, and database, all orchestrated efficiently using Docker Compose.

### Key Features
* **Authentication & Authorization:** Secure user login with Role-Based Access Control (RBAC).
* **Employer Dashboard:** Full CRUD operations on job postings and applicant tracking.
* **Job Seeker Dashboard:** Browse listings, submit applications, and track application history.
* **Responsive UI:** A modern, decoupled frontend built with React and Vite.
* **Persistent Storage:** Robust data management with MongoDB and Docker Volumes.

---

## 🛠️ Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Frontend** | React, Vite, JavaScript, HTML5, CSS3 |
| **Backend** | Node.js, Express.js |
| **Database** | MongoDB |
| **DevOps** | Docker, Docker Compose |

---
## 🐳 Dockerized Architecture

The application is decomposed into three primary services communicating over a Docker bridge network:

- **Frontend**: Serves the React application (Port `5173`)
- **Backend**: Handles business logic and RESTful API requests (Port `4000`)
- **MongoDB**: Handles persistent data storage (Port `27017`)

### Data Persistence
MongoDB data is stored using a **Docker named volume**. This ensures that data remains intact even if containers are stopped, removed, or rebuilt.

---

## ▶️ Getting Started

### Prerequisites
- Docker installed on your machine
- Docker Compose (bundled with Docker Desktop)

---

### Installation & Execution

#### Clone the Repository
git clone https://github.com/KaranGoyal134/Job-Portal.git
cd Job-Portal

## Spin up the Containers:

```bash
docker compose up -d --build
Access the App:
Frontend: http://localhost:5173

Backend API: http://localhost:4000

🔐 Environment Configuration
The application uses environment variables within the docker-compose.yml to manage:

MONGO_URI: The internal connection string for the database.

VITE_API_URL: The backend endpoint for frontend API calls.

🧠 Key Learnings & Skills
Developing complex MERN workflows and role-based logic.

Containerizing multi-service architectures with Docker.

Managing Docker Volumes for database state persistence.

Configuring Docker Networking for secure inter-service communication.

📌 Future Roadmap
 File Storage: Integrate AWS S3 or GridFS for resume uploads.

 Advanced Search: Implement job filtering by category, location, and salary.

 Notifications: Email alerts for application status updates.

 CI/CD: Automated testing and deployment pipelines.

📄 License
This project is intended for educational and demonstration purposes.

👨‍💻 Author
Karan Goyal
Computer Science Student
MERN Stack | Docker | DevOps


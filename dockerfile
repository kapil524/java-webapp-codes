# Use an official OpenJDK runtime as a parent image
FROM maven:3.8.1-openjdk-17-slim

# Set the working directory in the container
WORKDIR /app

# Install unzip
RUN apt-get update && apt-get install -y unzip

# Copy the contents of the project into the container at /app
COPY java-tech-test-feaure-devsecops-deploy.zip /app/

# Unzip the project
RUN unzip java-tech-test-feaure-devsecops-deploy.zip && \
    rm java-tech-test-feaure-devsecops-deploy.zip

# Set the working directory to the project directory
WORKDIR /app/java-tech-test-feaure-devsecops-deploy

# Build the application
RUN mvn clean install

# Expose the port that the application will run on
EXPOSE 8080

# Run the application
CMD ["mvn", "spring-boot:run"]


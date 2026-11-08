-- Doctor Appointment System
-- MySQL 8.0 schema
-- Review the database name before running this script.
--
-- Database layer for the application. Defines users and role data, doctor
-- profiles and schedules, generated appointment slots, and appointment
-- history with foreign keys, indexes, and the active-booking uniqueness rule.

CREATE DATABASE IF NOT EXISTS doctor_appointment_system
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE doctor_appointment_system;

CREATE TABLE IF NOT EXISTS users (
    user_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(254) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin', 'doctor', 'patient') NOT NULL DEFAULT 'patient',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_role_active (role, is_active)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS doctors (
    doctor_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL UNIQUE,
    specialty VARCHAR(120) NOT NULL,
    qualification VARCHAR(180) NULL,
    experience_years SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    consultation_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    bio TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_doctors_user
      FOREIGN KEY (user_id) REFERENCES users(user_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_doctor_experience CHECK (experience_years >= 0),
    CONSTRAINT chk_doctor_fee CHECK (consultation_fee >= 0)
) ENGINE=InnoDB;

-- One continuous working period per doctor per weekday (initial project assumption).
-- day_of_week: 1=Monday ... 7=Sunday.
CREATE TABLE IF NOT EXISTS doctor_schedules (
    schedule_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    doctor_id BIGINT UNSIGNED NOT NULL,
    day_of_week TINYINT UNSIGNED NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_available TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_schedules_doctor
      FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_doctor_weekday UNIQUE (doctor_id, day_of_week),
    CONSTRAINT chk_schedule_day CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT chk_schedule_time CHECK (start_time < end_time)
) ENGINE=InnoDB;

-- Slots are generated from schedules in 30-minute increments.
-- Keep historical slots rather than deleting them.
CREATE TABLE IF NOT EXISTS appointment_slots (
    slot_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    doctor_id BIGINT UNSIGNED NOT NULL,
    start_at DATETIME NOT NULL,
    end_at DATETIME NOT NULL,
    status ENUM('available', 'booked', 'blocked') NOT NULL DEFAULT 'available',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_slots_doctor
      FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_doctor_slot_start UNIQUE (doctor_id, start_at),
    CONSTRAINT chk_slot_duration CHECK (end_at > start_at),
    INDEX idx_slots_doctor_start_status (doctor_id, start_at, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS appointments (
    appointment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    patient_id BIGINT UNSIGNED NOT NULL,
    slot_id BIGINT UNSIGNED NOT NULL,
    status ENUM('confirmed', 'cancelled', 'completed') NOT NULL DEFAULT 'confirmed',
    booked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancelled_at DATETIME NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    -- Allows multiple historical cancelled/completed records for a slot,
    -- but only one confirmed appointment per slot.
    active_slot_id BIGINT UNSIGNED
      GENERATED ALWAYS AS (
        CASE WHEN status = 'confirmed' THEN slot_id ELSE NULL END
      ) STORED,

    CONSTRAINT fk_appointments_patient
      FOREIGN KEY (patient_id) REFERENCES users(user_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_appointments_slot
      FOREIGN KEY (slot_id) REFERENCES appointment_slots(slot_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_one_confirmed_booking_per_slot UNIQUE (active_slot_id),
    INDEX idx_appointments_patient_status (patient_id, status),
    INDEX idx_appointments_slot_status (slot_id, status)
) ENGINE=InnoDB;

-- Notes for the PHP application:
-- 1. Public signup must always create role='patient'; never accept a role from the form.
-- 2. Create the first admin securely from a one-time setup script or a CLI script using
--    password_hash(). Do not hard-code or publish an admin password.
-- 3. Booking should run in a transaction:
--      START TRANSACTION;
--      SELECT slot_id, status FROM appointment_slots
--       WHERE slot_id = ? FOR UPDATE;
--      Confirm the slot is available and in the future, within the 7-day window,
--      and the doctor account is active. Then insert the appointment and set slot
--      status='booked'. COMMIT; otherwise ROLLBACK.
-- 4. Cancellation should run in a transaction, authorize the patient or assigned doctor,
--    require start_at > NOW(), update appointment status='cancelled', set cancelled_at,
--    and set slot status='available'.
-- 5. When an appointment is completed, update status='completed'. Do not delete history.
-- 6. On doctor deactivation, set users.is_active=0; preserve the doctor profile and records.
-- 7. Use PHP's password_hash()/password_verify(), prepared statements, session regeneration,
--    CSRF tokens, and server-side role/ownership checks.

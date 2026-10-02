package com.jesusanswers.api.journey;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import org.springframework.data.domain.Limit;
import org.springframework.data.jpa.repository.JpaRepository;

interface AppUserRepository extends JpaRepository<AppUser, UUID> {
    Optional<AppUser> findByFirebaseUid(String firebaseUid);
}

interface JourneyEntryRepository extends JpaRepository<JourneyEntry, UUID> {
    List<JourneyEntry> findByUserIdOrderByCreatedAtDesc(UUID userId, Limit limit);

    Optional<JourneyEntry> findByIdAndUserId(UUID id, UUID userId);
}

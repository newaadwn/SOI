const {Timestamp} = require("firebase-admin/firestore");

/**
 * 30일이 지난 소프트 삭제된 사진들을 영구 삭제하는 함수
 * @param {Object} params - 파라미터 객체
 * @param {import("firebase-admin/firestore").Firestore} params.db
 * @param {import("firebase-admin/storage").Storage} params.storage
 * @param {Object} params.supabase - Supabase 클라이언트
 * @param {import("firebase-functions").logger} params.logger - 로거
 */
async function cleanupDeletedPhotos({db, storage, supabase, logger}) {
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const logMsg = `Starting cleanup of photos deleted before: ` +
    `${thirtyDaysAgo.toISOString()}`;
  logger.info(logMsg);

  let totalDeleted = 0;
  let totalErrors = 0;

  try {
    // 30일 이전에 삭제된 사진들 찾기
    const deletedPhotosQuery = await db
        .collectionGroup("photos")
        .where("status", "==", "deleted")
        .where("deletedAt", "<=", Timestamp.fromDate(thirtyDaysAgo))
        .get();

    const photoCount = deletedPhotosQuery.docs.length;
    logger.info(`Found ${photoCount} photos to permanently delete`);

    // 배치 처리로 성능 최적화
    const batchSize = 50;
    for (let i = 0; i < deletedPhotosQuery.docs.length; i += batchSize) {
      const batch = deletedPhotosQuery.docs.slice(i, i + batchSize);

      await Promise.all(
          batch.map(async (doc) => {
            try {
              const data = doc.data();
              const photoId = doc.id;

              logger.info(`Permanently deleting photo: ${photoId}`);

              // 1. Storage에서 이미지 파일 삭제
              if (data.imageUrl) {
                await deleteAnyStorageByUrl(data.imageUrl,
                    {storage, supabase, logger});
              }

              // 2. Storage에서 오디오 파일 삭제
              if (data.audioUrl) {
                await deleteAnyStorageByUrl(data.audioUrl,
                    {storage, supabase, logger});
              }

              // 3. 관련 댓글 삭제
              await deletePhotoComments(db, photoId, logger);

              // 4. 관련 반응(이모티콘) 삭제
              await deletePhotoReactions(db, photoId, logger);

              // 5. Firestore 문서 삭제
              await doc.ref.delete();

              totalDeleted++;
              logger.info(`Successfully deleted photo: ${photoId}`);
            } catch (error) {
              totalErrors++;
              logger.error(`Failed to delete photo ${doc.id}:`, error);
            }
          }),
      );
    }

    const completionMsg = `Cleanup completed. Deleted: ${totalDeleted}, ` +
      `Errors: ${totalErrors}`;
    logger.info(completionMsg);

    return {
      success: true,
      deletedCount: totalDeleted,
      errorCount: totalErrors,
    };
  } catch (error) {
    logger.error("Error during cleanup:", error);
    throw error;
  }
}

/**
 * Storage 파일 삭제 (Firebase Storage 또는 Supabase)
 */
async function deleteAnyStorageByUrl(url, {storage, supabase, logger}) {
  try {
    // Firebase Storage URL 패턴 확인
    const isFirebase = url.includes("firebasestorage.googleapis.com") ||
      url.includes("firebase");
    if (isFirebase) {
      const ref = storage.refFromURL(url);
      await ref.delete();
      logger.info(`Deleted Firebase Storage file: ${url}`);
    } else if (url.includes("supabase") && supabase) {
      // Supabase Storage URL 패턴 확인
      // Supabase URL에서 파일 경로 추출
      const urlParts = url.split("/");
      const bucketIndex = urlParts.findIndex((part) => part === "object");
      if (bucketIndex !== -1 && bucketIndex + 2 < urlParts.length) {
        const bucket = urlParts[bucketIndex + 1];
        const filePath = urlParts.slice(bucketIndex + 2).join("/");

        const {error} = await supabase.storage
            .from(bucket)
            .remove([filePath]);

        if (error) {
          logger.warn(`Failed to delete Supabase file: ${url}`, error);
        } else {
          logger.info(`Deleted Supabase Storage file: ${url}`);
        }
      }
    } else {
      logger.warn(`Unknown storage URL format: ${url}`);
    }
  } catch (error) {
    logger.warn(`Failed to delete storage file: ${url}`, error);
  }
}

/**
 * 사진과 관련된 댓글들 삭제
 */
async function deletePhotoComments(db, photoId, logger) {
  try {
    const commentsQuery = await db
        .collection("comment_records")
        .where("photoId", "==", photoId)
        .get();

    const batch = db.batch();
    let batchCount = 0;

    for (const doc of commentsQuery.docs) {
      const commentData = doc.data();

      // 댓글 오디오 파일도 삭제 (별도 처리 필요시)
      if (commentData.audioUrl) {
        const audioMsg = `Comment audio found for deletion: ` +
          `${commentData.audioUrl}`;
        logger.info(audioMsg);
      }

      batch.delete(doc.ref);
      batchCount++;

      // Firestore 배치 제한 (500개)
      if (batchCount >= 450) {
        await batch.commit();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    const commentCount = commentsQuery.docs.length;
    logger.info(`Deleted ${commentCount} comments for photo: ${photoId}`);
  } catch (error) {
    logger.error(`Failed to delete comments for photo ${photoId}:`, error);
  }
}

/**
 * 사진과 관련된 반응들 삭제
 */
async function deletePhotoReactions(db, photoId, logger) {
  try {
    const reactionsQuery = await db
        .collectionGroup("reactions")
        .where("photoId", "==", photoId)
        .get();

    const batch = db.batch();
    let batchCount = 0;

    for (const doc of reactionsQuery.docs) {
      batch.delete(doc.ref);
      batchCount++;

      if (batchCount >= 450) {
        await batch.commit();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    const reactionCount = reactionsQuery.docs.length;
    logger.info(`Deleted ${reactionCount} reactions for photo: ${photoId}`);
  } catch (error) {
    logger.error(`Failed to delete reactions for photo ${photoId}:`, error);
  }
}

module.exports = {cleanupDeletedPhotos};

//
//  COpenCombineHelpers.h
//  
//
//  Created by Sergej Jaskiewicz on 23/09/2019.
//

#ifndef COPENCOMBINEHELPERS_H
#define COPENCOMBINEHELPERS_H

#include <stdint.h>
#include <stddef.h>

#if __has_attribute(swift_name)
# define OPENCOMBINE_SWIFT_NAME(_name) __attribute__((swift_name(#_name)))
#else
# define OPENCOMBINE_SWIFT_NAME(_name)
#endif

#ifdef __cplusplus
extern "C" {
#endif

#pragma mark - CombineIdentifier

uint64_t opencombine_next_combine_identifier(void)
    OPENCOMBINE_SWIFT_NAME(nextCombineIdentifier());

#pragma mark - OpenCombineUnfairLock

/// A wrapper around an opaque pointer for type safety in Swift.
typedef struct OpenCombineUnfairLock {
    void* _Nonnull opaque;
} OPENCOMBINE_SWIFT_NAME(UnfairLock) OpenCombineUnfairLock;

/// Allocates a lock object. The allocated object must be destroyed by calling
/// the destroy() method.
OpenCombineUnfairLock opencombine_unfair_lock_alloc(void)
    OPENCOMBINE_SWIFT_NAME(UnfairLock.allocate());

void opencombine_unfair_lock_lock(OpenCombineUnfairLock)
    OPENCOMBINE_SWIFT_NAME(UnfairLock.lock(self:));

void opencombine_unfair_lock_unlock(OpenCombineUnfairLock)
    OPENCOMBINE_SWIFT_NAME(UnfairLock.unlock(self:));

void opencombine_unfair_lock_dealloc(OpenCombineUnfairLock lock)
    OPENCOMBINE_SWIFT_NAME(UnfairLock.deallocate(self:));

#pragma mark - OpenCombineUnfairRecursiveLock

/// A wrapper around an opaque pointer for type safety in Swift.
typedef struct OpenCombineUnfairRecursiveLock {
    void* _Nonnull opaque;
} OPENCOMBINE_SWIFT_NAME(UnfairRecursiveLock) OpenCombineUnfairRecursiveLock;

OpenCombineUnfairRecursiveLock opencombine_unfair_recursive_lock_alloc(void)
    OPENCOMBINE_SWIFT_NAME(UnfairRecursiveLock.allocate());

void opencombine_unfair_recursive_lock_lock(OpenCombineUnfairRecursiveLock)
    OPENCOMBINE_SWIFT_NAME(UnfairRecursiveLock.lock(self:));

void opencombine_unfair_recursive_lock_unlock(OpenCombineUnfairRecursiveLock)
    OPENCOMBINE_SWIFT_NAME(UnfairRecursiveLock.unlock(self:));

void opencombine_unfair_recursive_lock_dealloc(OpenCombineUnfairRecursiveLock lock)
    OPENCOMBINE_SWIFT_NAME(UnfairRecursiveLock.deallocate(self:));

#pragma mark - Type metadata

#ifdef __cplusplus
typedef bool OpenCombineBool;
#else
typedef _Bool OpenCombineBool;
#endif

typedef OpenCombineBool(*_Nonnull OpenCombineFieldEnumerator)(
    void* _Nullable enumeratorContext,
    const char* _Nonnull fieldName,
    size_t fieldOffset,
    const void* _Nonnull fieldTypeMetadataPtr
);

OpenCombineBool
opencombine_enumerate_class_fields(
    const void* _Nonnull type_metadata,
    void* _Nullable enumerator_context,
    OpenCombineFieldEnumerator enumerator
) OPENCOMBINE_SWIFT_NAME(enumerateClassFields(typeMetadata:enumeratorContext:enumerator:));

#ifdef __cplusplus
} // extern "C"
#endif

#endif /* COPENCOMBINEHELPERS_H */

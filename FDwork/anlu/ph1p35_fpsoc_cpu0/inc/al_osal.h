/*
 * Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

/*****************************************************************************
*****************************************************************************/

#ifndef __AL_OSAL_H_
#define __AL_OSAL_H_

#ifdef __cplusplus
extern "C"{
#endif /* __cplusplus */

#include "al_errno.h"
#include "al_type.h"
#include "al_intr.h"

#ifdef USE_RTOS
#if defined(RTOS_RTTHREAD) || defined(RTOS_RTTHREAD_NANO)
#include <rtthread.h>
#include <rthw.h>

/*----------------------------------------------*
 * MUTEX API.*
 *----------------------------------------------*/

#define AL_WAITFOREVER           (AL_U32)RT_WAITING_FOREVER
#define AL_WAITING_NO            RT_WAITING_NO
typedef struct
{
    struct rt_mutex     Thread_Lock;
    AL_S64              Isr_Lock;
} AL_Lock;
typedef AL_Lock* AL_Lock_t;

/**
 * This function initializes a lock for thread synchronization.
 *
 * @param Lock The lock object to be initialized.
 * @param Name The name of the lock, used for debugging purposes.
 * @return AL_S32 Status code indicating success or failure of the operation.
 *         Typically returns AL_OK on success.
 */
static inline AL_S32 AlOsal_Lock_Init(AL_Lock_t Lock, const char* Name)
{
    return rt_mutex_init(&Lock->Thread_Lock, Name, RT_IPC_FLAG_PRIO);
}

/**
 *
 * This function attempts to take the lock. If the scheduler is currently active and the function
 * is called from a thread context, it will attempt to lock using the mutex. If called from
 * an interrupt context, it will disable interrupts instead.
 *
 * @param Lock The lock object to be taken.
 * @param Timeout The maximum time to wait for the lock to become available.
 * @return AL_S32 Status code indicating success or failure of the operation.
 *         Returns AL_OK if the lock was successfully acquired, and an error code otherwise.
 */
static inline AL_S32 AlOsal_Lock_Take(AL_Lock_t Lock, AL_U32 Timeout)
{
    /* If the scheduler is started and in thread context */
    if (rt_interrupt_get_nest() == 0 && rt_thread_self() != RT_NULL) {
        return rt_mutex_take(&Lock->Thread_Lock, Timeout);
    }
    else {
        Lock->Isr_Lock = rt_hw_interrupt_disable();
        return AL_OK;
    }
}

/**
 *
 * Similar to AlOsal_Lock_Take, this function checks if the call is made from a thread context
 * or an interrupt context. If in thread context, it releases the mutex. If in ISR context,
 * it re-enables interrupts that were previously disabled.
 *
 * @param Lock The lock object to be released.
 * @return AL_S32 Status code indicating success or failure of the operation.
 *         Typically returns AL_OK on success.
 */
static inline AL_S32 AlOsal_Lock_Release(AL_Lock_t Lock)
{
    /* If the scheduler is started and in thread context */
    if (rt_interrupt_get_nest() == 0 && rt_thread_self() != RT_NULL) {
        return rt_mutex_release(&Lock->Thread_Lock);
    }
    else {
        rt_hw_interrupt_enable(Lock->Isr_Lock);
        return AL_OK;
    }
}

/*----------------------------------------------*
 * Semaphore API.*
 *----------------------------------------------*/

typedef struct rt_semaphore  AL_Semaphore;
typedef struct rt_semaphore* AL_Semaphore_t;

/**
 *
 * This function initializes a semaphore object with a specified name and an initial value.
 * It should be called before using the semaphore for controlling access to shared resources
 * in a concurrent environment.
 *
 * @param Semaphore Pointer to the semaphore object to be initialized.
 * @param Name A string representing the name of the semaphore for
 *             debugging purposes.
 * @param Value The initial value of the semaphore, which determines
 *              the number of resources available at initialization.
 * @return AL_S32 Status code indicating success or failure.
 *         Returns AL_OK on successful initialization of the semaphore.
 */
static inline AL_S32 AlOsal_Sem_Init(AL_Semaphore_t Semaphore, const char* Name, AL_S32 Value)
{
    return rt_sem_init(Semaphore, Name, Value, RT_IPC_FLAG_PRIO);
}

/**
 *
 * This function attempts to take (decrement) the semaphore. If the semaphore's value is greater
 * than zero, it decrements the value and returns immediately. If the value is zero,
 * it will block until the semaphore is available or the specified timeout period is reached.
 *
 * @param Semaphore Pointer to the semaphore object to be taken.
 * @param Timeout The maximum time (in milliseconds) to wait for the
 *                semaphore to become available.
 * @return AL_S32 Status code indicating success or failure.
 *         Returns AL_OK if the semaphore was successfully taken, or an error code if the take operation fails or times out.
 */
static inline AL_S32 AlOsal_Sem_Take(AL_Semaphore_t Semaphore, AL_U32 Timeout)
{
    return rt_sem_take(Semaphore, Timeout);
}

/**
 *
 * This function releases (increments) the semaphore, indicating that a resource has become available.
 * This allows other contexts waiting on this semaphore to proceed.
 *
 * @param Semaphore Pointer to the semaphore object to be released.
 * @return AL_S32 Status code indicating success or failure.
 *         Typically returns AL_OK on successful release of the semaphore.
 */
static inline AL_S32 AlOsal_Sem_Release(AL_Semaphore_t Semaphore)
{
    return rt_sem_release(Semaphore);
}

/*----------------------------------------------*
 * Mailbox API.*
 *----------------------------------------------*/

typedef struct
{
    AL_Semaphore    Semaphore;
    AL_U64          Msg;
    AL_S32          size;
    volatile AL_S16 entry;                         /**< index of messages in msg_pool */
} AL_MailBox;
typedef AL_MailBox*  AL_MailBox_t;

/**
 *
 * This function initializes a mailbox object with the specified name. It sets up the associated semaphore to
 * control access to the mailbox and initializes the mailbox's internal message storage. Initially, the mailbox
 * is empty and ready to send and receive messages.
 *
 * @param MailBox Pointer to the mailbox object to be initialized.
 * @param Name A string representing the name of the mailbox for debugging or logging purposes.
 * @return AL_S32 Status code indicating success or failure.
 *         Returns AL_OK on successful initialization of the mailbox,
 *         or an error code if the semaphore initialization fails.
 */
static inline AL_S32 AlOsal_Mb_Init(AL_MailBox_t MailBox, const char* Name)
{
    AL_S64 Ret = AL_OK;

    Ret = rt_sem_init(&MailBox->Semaphore, Name, 0, RT_IPC_FLAG_PRIO);
    if (Ret != AL_OK) {
        return Ret;
    }

    MailBox->Msg   = 0;
    MailBox->size  = 1;
    MailBox->entry = 0;

    return Ret;

}

/**
 *
 * This function places a message into the mailbox. It sets the message field to the value provided
 * and signals that a message is available by releasing the associated semaphore. If the mailbox is full,
 * the behavior depends on the implementation (blocking, returning an error, etc.).
 *
 * @param MailBox Pointer to the mailbox object where the message will be sent.
 * @param Msg Pointer to the message to be sent. The message is expected to be a pointer
 *            to an AL_U64 type as the mailbox stores a single 64-bit message.
 * @return AL_S32 Status code indicating success or failure.
 *         Returns AL_OK if the message was successfully sent,
 *         or an error code if there was an issue with sending.
 */
static inline AL_S32 AlOsal_Mb_Send(AL_MailBox_t MailBox, AL_VOID * Msg)
{
    MailBox->Msg = *(AL_U64 *)Msg;
    __COMPILER_BARRIER();
    MailBox->entry = 1;

    return rt_sem_release(&MailBox->Semaphore);
}

/**
 *
 * This function attempts to retrieve a message from the mailbox. It will block until a message
 * is available or the specified timeout is reached. If a message is received, it retrieves
 * the message value and clears the mailbox entry state.
 *
 * @param MailBox Pointer to the mailbox object from which the message will be received.
 * @param Msg Pointer to a variable where the received message will be stored.
 *            This should point to an AL_U64 type to retrieve the message value.
 * @param Timeout The maximum time (in milliseconds) to wait for a message to become available
 *                in the mailbox. If the timeout period elapses without receiving a message, an error is returned.
 * @return AL_S32 Status code indicating success or failure.
 *         Returns AL_OK if the message was successfully received,
 *         or AL_ERR_UNAVAILABLE if no message was available within the timeout period.
 */
static inline AL_S32 AlOsal_Mb_Receive(AL_MailBox_t MailBox, AL_VOID* Msg, AL_U32 Timeout)
{
    AL_S32 flag = (AL_S32)rt_sem_take(&MailBox->Semaphore, (rt_int32_t)Timeout);

    if (flag == AL_OK) {
        MailBox->entry = 0;
        __COMPILER_BARRIER();
        *(AL_U64 *)Msg = MailBox->Msg;
        return AL_OK;
    }

    return AL_ERR_UNAVAILABLE;
}

/*----------------------------------------------*
 * Critical API for specific devices*
 *----------------------------------------------*/

/**
 *
 * This function is used to enter a critical section, preventing interrupts from being serviced.
 * It ensures that concurrent access to shared resources is controlled, allowing for safe
 * modifications or operations on device-related data.
 *
 * The parameters DevIntrId and Condition are currently not used
 * within the function body but may be intended for future
 * enhancements or to maintain a consistent API.
 *
 * @param DevIntrId Identifier for the device interrupt. Currently unused but may serve as a reference for future developments.
 * @param Condition A boolean value representing the condition under which the critical section is entered.
 *                  Currently unused but included for API consistency.
 * @return None.
 */
static inline AL_VOID AlOsal_EnterDevCtritical(AL_U32 DevIntrId, AL_BOOL Condition)
{
    (AL_VOID)DevIntrId;
    (AL_VOID)Condition;
    rt_enter_critical();
}

/**
 *
 * This function is used to exit a critical section, allowing interrupts to be serviced again.
 * It should be called after the completion of operations that require exclusive access to
 * shared resources to ensure the system's stability and consistency.
 *
 * Similar to the enter function, the parameters DevIntrId and Condition are currently not utilized
 * but are present for API consistency and potential future use.
 *
 * @param DevIntrId Identifier for the device interrupt. Currently unused but may serve as a reference for future developments.
 * @param Condition A boolean value representing the condition under which the critical section is exited.
 *                  Currently unused but included for API consistency.
 */
static inline AL_VOID AlOsal_ExitDevCtritical(AL_U32 DevIntrId, AL_BOOL Condition)
{
    (AL_VOID)DevIntrId;
    (AL_VOID)Condition;
    rt_exit_critical();
}


/*----------------------------------------------*
 * Critical API.*
 *----------------------------------------------*/
/**
 *
 * This function is used to enter a critical section, preventing any interrupts from being serviced.
 * It's important for ensuring  exclusive access to shared resources, especially in a multi-threaded environment.
 *
 * @return AL_U64 A flag indicating the result of the operation, currently always returns AL_OK.
 */
static inline AL_U64 ALOsal_EnterCritical(AL_VOID)
{
    rt_enter_critical();
    return AL_OK;
}

/**
 *
 * This function is used to exit a critical section that was previously entered with ALOsal_EnterCritical.
 * It restores the state of interrupts, allowing them to be serviced once again.
 *
 * @param flag A flag previously returned by ALOsal_EnterCritical. Currently not used
 *            but included for consistency in the API.
 * @return None.
 */
static inline AL_VOID ALOsal_ExitCritical(AL_U64 flag)
{
    rt_exit_critical();
}

/*----------------------------------------------*
 * Critical API.*
 *----------------------------------------------*/
/**
 *
 * This function suspends the execution of the calling threadnfor the specified amount of time
 * in milliseconds. It first checks if the scheduler is active and whether the calling context is a thread.
 *
 * @param Time The duration in milliseconds for which the calling thread should sleep.
 * @return None.
 */
static inline AL_VOID AlOsal_Sleep(AL_U32 Time)
{
    /* If the scheduler is started and in thread context */
    if (rt_interrupt_get_nest() == 0 && rt_thread_self() != RT_NULL) {
        return (AL_VOID)rt_thread_mdelay(Time);
    }
    else {
        return;
    }
}

#endif
#ifdef RTOS_FREERTOS

#include <FreeRTOS.h>
#include "semphr.h"

extern volatile uint64_t ullCriticalNesting;
extern volatile uint64_t uxCriticalNesting;

#ifdef SMP
extern volatile uint64_t ullPortInterruptNesting[];
#else
extern volatile uint64_t ullPortInterruptNesting;
#endif

/**
 *
 * This function checks whether the system is currently within an interrupt context
 * by evaluating the interrupt nesting level.
 *
 * @return AL_BOOL Returns AL_TRUE if in an interrupt context, otherwise returns AL_FALSE.
 */
static AL_BOOL AlOsal_In_Intr( void )
{

#ifdef SMP
extern AL_U32 AlGic_CorePos(void);
	if (ullPortInterruptNesting[AlGic_CorePos()]) {
		return AL_TRUE;
	} else {
		return AL_FALSE;
	}
#else
	if (ullPortInterruptNesting) {
		return AL_TRUE;
	} else {
		return AL_FALSE;
	}
#endif
}

/*----------------------------------------------*
 * MUTEX API.*
 *----------------------------------------------*/

#define AL_WAITFOREVER           (AL_U32)portMAX_DELAY
#define AL_WAITING_NO            0
typedef struct
{
    StaticSemaphore_t        Thread_Lock_buffer;
    SemaphoreHandle_t        Thread_Lock;
    AL_S64                   Isr_Lock;
} AL_Lock;
typedef AL_Lock* AL_Lock_t;

/**
 *
 * This function initializes the mutex lock by creating a mutex object statically using FreeRTOS.
 * It takes a pointer to a lock structure and an optional name for the lock, which can be used
 * for debugging purposes.
 *
 * @param Lock A pointer to the lock structure to initialize.
 * @param Name A string representing the name of the lock (for debugging purposes).
 *
 * @return AL_S32 Returns AL_OK on successful initialization,
 *         or a corresponding error code on failure.
 */
static inline AL_S32 AlOsal_Lock_Init(AL_Lock_t Lock, const char* Name)
{
    Lock->Thread_Lock = xSemaphoreCreateMutexStatic(&Lock->Thread_Lock_buffer);

    configASSERT(Lock->Thread_Lock);

    return AL_OK;
}

/**
 *
 * This function attempts to take the mutex lock. If called from within an interrupt context,
 * it uses the ISR version of the semaphore take function.
 *
 * @param Lock A pointer to the lock structure to lock.
 * @param Timeout The maximum time to wait for the lock in ticks (only applicable when not in interrupt).
 *
 * @return AL_S32 Returns AL_OK if the lock is successfully acquired, or AL_ERR_UNAVAILABLE if it is not available.
 */
static inline AL_S32 AlOsal_Lock_Take(AL_Lock_t Lock, AL_U32 Timeout)
{
    if (AlOsal_In_Intr()){
        AL_S32 Ret;
        BaseType_t xHigherPriorityTaskWoken = pdFALSE;
        Ret = xSemaphoreTakeFromISR(Lock->Thread_Lock, &xHigherPriorityTaskWoken);
        if (Ret == pdPASS) {
            portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
            return AL_OK;
        } else {
            return AL_ERR_UNAVAILABLE;
        }
    } else {
        return (xSemaphoreTake(Lock->Thread_Lock, (TickType_t) Timeout) == pdPASS)? AL_OK : AL_ERR_UNAVAILABLE;
    }
}

/**
 *
 * This function releases the mutex lock. If called from within an interrupt context,
 * it uses the ISR version of the semaphore give function.
 *
 * @param Lock A pointer to the lock structure to release.
 *
 * @return AL_S32 Returns AL_OK if successfully released,
 *         or AL_ERR_UNAVAILABLE if the lock is not held.
 */
static inline AL_S32 AlOsal_Lock_Release(AL_Lock_t Lock)
{
    if (AlOsal_In_Intr()) {
        AL_S32 Ret;
        BaseType_t xHigherPriorityTaskWoken = pdFALSE;
        Ret = xSemaphoreGiveFromISR(Lock->Thread_Lock, &xHigherPriorityTaskWoken);
        if (Ret == pdPASS) {
            portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
            return AL_OK;
        } else {
            return AL_ERR_UNAVAILABLE;
        }
    } else {
        return (xSemaphoreGive(Lock->Thread_Lock) == pdPASS)? AL_OK : AL_ERR_UNAVAILABLE;
    }
}

/*----------------------------------------------*
 * Semaphore API.*
 *----------------------------------------------*/
typedef struct
{
    StaticSemaphore_t Semaphore_Buffer;
    SemaphoreHandle_t Semaphore_Handle;
} AL_Semaphore;

typedef AL_Semaphore* AL_Semaphore_t;

/**
 *
 * This function initializes a counting semaphore by allocating a static semaphore object.
 * It is suitable for use in both task and ISR contexts. The initial count and maximum count
 * values are specified as parameters.
 *
 * @param Semaphore A pointer to the semaphore structure to initialize.
 * @param Name A string representing the name of the semaphore (for debugging purposes).
 * @param Value The initial count value for the semaphore.
 * @param MaxCount The maximum count value that the semaphore can reach.
 *
 * @return AL_S32 Returns AL_OK on successful initialization,
 *         or a corresponding error code on failure.
 */
static inline AL_S32 AlOsal_Sem_Init(AL_Semaphore_t Semaphore, const char* Name, AL_S32 Value, AL_S64 MaxCount)
{
    AL_UNUSED(Name);

    Semaphore->Semaphore_Handle = xSemaphoreCreateCountingStatic(MaxCount, Value, &Semaphore->Semaphore_Buffer);

    configASSERT(Semaphore->Semaphore_Handle);

    return AL_OK;
}

/**
 *
 * This function attempts to take the semaphore. If called from within an interrupt context,
 * it uses the ISR versionb of the semaphore take function.
 *
 * @param Semaphore A pointer to the semaphore structure to take.
 * @param Timeout The maximum time to wait for the semaphore in ticks (only applicable when not in interrupt).
 *
 * @return AL_S32 Returns AL_OK if the semaphore is successfully taken,
 *         or AL_ERR_UNAVAILABLE if it is not available.
 */
static inline AL_S32 AlOsal_Sem_Take(AL_Semaphore_t Semaphore, AL_U32 Timeout)
{
    if (AlOsal_In_Intr()) {
        AL_S32 Ret;
        BaseType_t xHigherPriorityTaskWoken = pdFALSE;
        Ret = xSemaphoreTakeFromISR(Semaphore->Semaphore_Handle, &xHigherPriorityTaskWoken);
        if (Ret == pdPASS) {
            portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
            return AL_OK;
        } else {
            return AL_ERR_UNAVAILABLE;
        }
    } else {
        return (xSemaphoreTake(Semaphore->Semaphore_Handle, (TickType_t) Timeout) == pdPASS)? AL_OK : AL_ERR_UNAVAILABLE;
    }
}

/**
 *
 * This function releases the semaphore, incrementing its count. If called from within an interrupt context,
 * it uses the ISR version of the semaphore give function.
 *
 * @param Semaphore A pointer to the semaphore structure to release.
 *
 * @return AL_S32 Returns AL_OK if successfully released, or AL_ERR_UNAVAILABLE if the semaphore was not held.
 */
static inline AL_S32 AlOsal_Sem_Release(AL_Semaphore_t Semaphore)
{
    if (AlOsal_In_Intr()) {
        AL_S32 Ret;
        BaseType_t xHigherPriorityTaskWoken = pdFALSE;
        Ret = xSemaphoreGiveFromISR(Semaphore->Semaphore_Handle, &xHigherPriorityTaskWoken);
        if (Ret == pdPASS) {
            portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
            return AL_OK;
        } else {
            return AL_ERR_UNAVAILABLE;
        }
    } else {
        return (xSemaphoreGive(Semaphore->Semaphore_Handle) == pdPASS)? AL_OK : AL_ERR_UNAVAILABLE;
    }
}

/*----------------------------------------------*
 * Mailbox API.*
 *----------------------------------------------*/

typedef struct
{
    AL_Semaphore    Semaphore;
    AL_U64          Msg;
    AL_S32          size;
    volatile AL_S16 entry;                         /**< index of messages in msg_pool */
} AL_MailBox;
typedef AL_MailBox*  AL_MailBox_t;

/**
 *
 * This function initializes a mailbox by creating a counting semaphore for signaling message availability.
 * The mailboxb is set to hold a single message, initially empty.
 *
 * @param MailBox A pointer to the mailbox structure to initialize.
 * @param Name A string representing the name of the mailbox (for debugging purposes).
 *
 * @return AL_S32 Returns AL_OK on successful initialization, or a corresponding error code on failure.
 */
static inline AL_S32 AlOsal_Mb_Init(AL_MailBox_t MailBox, const char* Name)
{
    MailBox->Semaphore.Semaphore_Handle = xSemaphoreCreateCountingStatic(1, 0, &MailBox->Semaphore.Semaphore_Buffer);

    configASSERT(MailBox->Semaphore.Semaphore_Handle);

    MailBox->Msg   = 0;
    MailBox->size  = 1;
    MailBox->entry = 0;

    return AL_OK;
}

/**
 *
 * This function sends a message to the mailbox. It copies the message into the mailbox structure
 * and signals that a new message is available by giving the semaphore. If called from an interrupt context,
 * it uses the ISR version of the semaphore give function.
 *
 * @param MailBox A pointer to the mailbox structure to which the message is being sent.
 * @param Msg A pointer to the message to send (expected to be of type AL_U64).
 *
 * @return AL_S32 Returns AL_OK if the message is successfully sent, or AL_ERR_UNAVAILABLE if the semaphore was not available.
 */
static inline AL_S32 AlOsal_Mb_Send(AL_MailBox_t MailBox, AL_VOID * Msg)
{
    MailBox->Msg = *(AL_U64 *)Msg;
    __COMPILER_BARRIER();
    MailBox->entry = 1;

    if (AlOsal_In_Intr()) {
        AL_S32 Ret;
        BaseType_t xHigherPriorityTaskWoken = pdFALSE;
        Ret = xSemaphoreGiveFromISR(MailBox->Semaphore.Semaphore_Handle, &xHigherPriorityTaskWoken);
        if (Ret == pdPASS) {
            portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
        }
        return AL_OK;
    } else {
        return (xSemaphoreGive(MailBox->Semaphore.Semaphore_Handle) == pdPASS)? AL_OK : AL_ERR_UNAVAILABLE;
    }
}

/**
 *
 * This function attempts to receive a message from the mailbox. It waits for the semaphore
 * to be signaled before copying the message from the mailbox structure to the provided message
 * pointer. If called from an interrupt context, it uses the ISR version of the semaphore take function.
 *
 * @param MailBox A pointer to the mailbox structure from which to receive the message.
 * @param Msg A pointer to a location where the received message will be stored (expected to be of type AL_U64).
 * @param Timeout The maximum time to wait for a message, specified in ticks (only applicable when not in interrupt).
 *
 * @return AL_S32 Returns AL_OK if the message is successfully received,
 *         or AL_ERR_UNAVAILABLE if the message was not available within the specified timeout.
 */
static inline AL_S32 AlOsal_Mb_Receive(AL_MailBox_t MailBox, AL_VOID* Msg, AL_U32 Timeout)
{
    AL_S32 Ret;

    if (AlOsal_In_Intr()) {
        BaseType_t xHigherPriorityTaskWoken = pdFALSE;
        Ret = xSemaphoreTakeFromISR(MailBox->Semaphore.Semaphore_Handle, &xHigherPriorityTaskWoken);
        if (Ret == pdPASS) {
            portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
            Ret = AL_OK;
        } else {
            Ret = AL_ERR_UNAVAILABLE;
        }
    } else {
        Ret = (xSemaphoreTake(MailBox->Semaphore.Semaphore_Handle, (TickType_t) Timeout) == pdPASS)? AL_OK : AL_ERR_UNAVAILABLE;
    }

    if (Ret == AL_OK) {
        MailBox->entry = 0;
        __COMPILER_BARRIER();
        *(AL_U64 *)Msg = MailBox->Msg;
        return AL_OK;
    }

    return AL_ERR_UNAVAILABLE;
}

/*----------------------------------------------*
 * Critical API for specific devices*
 *----------------------------------------------*/

/**
 *
 * This function disables the specified device interrupt if the provided condition is true.
 * It should be used to protect critical sections of code where concurrent access by
 * interrupts could cause issues.
 *
 * @param DevIntrId The identifier of the device interrupt to disable.
 * @param Condition A boolean value that determines whether to disable the interrupt.
 *                  If true, the interrupt will be disabled.
 *
 * @return AL_VOID This function does not return a value.
 */
static inline AL_VOID AlOsal_EnterDevCtritical(AL_U32 DevIntrId, AL_BOOL Condition)
{
    if (Condition) {
        AlIntr_SetInterrupt(DevIntrId, AL_FUNC_DISABLE);
    }
}

/**
 *
 * This function enables the specified device interrupt if the provided condition is true.
 * It should be used to gracefully exit the critical section of code, restoring interrupt handling.
 *
 * @param DevIntrId The identifier of the device interrupt to enable.
 * @param Condition A boolean value that determines whether to enable the interrupt.
 *                  If true, the interrupt will be enabled.
 *
 * @return AL_VOID This function does not return a value.
 */
static inline AL_VOID AlOsal_ExitDevCtritical(AL_U32 DevIntrId, AL_BOOL Condition)
{
    if (Condition) {
        AlIntr_SetInterrupt(DevIntrId, AL_FUNC_ENABLE);
    }
}

/*----------------------------------------------*
 * Critical API.*
 *----------------------------------------------*/

/**
 *
 * This function saves the current state of the local interrupt mask, allowing the caller
 * to re-enable or disable interrupts as needed when exiting the critical section.
 *
 * @return AL_U64 Returns the saved interrupt mask, which can be used later to restore
 *         the interrupt state when exiting the critical section.
 */
static inline AL_U64 ALOsal_EnterCritical(AL_VOID)
{
    if (AlOsal_In_Intr()) {
        return (AL_U64)taskENTER_CRITICAL_FROM_ISR();
    } else {
        taskENTER_CRITICAL();
        return 0;
    }
}

/**
 *
 * This function restores the local interrupt state using the flag provided by the caller
 * when entering the critical section. It should be called to re-enable interrupts as part
 * of maintaining proper interrupt handling.
 *
 * @param Flag The interrupt mask saved when entering the critical section. This is restored to
 *             re-enable the appropriate interrupts.
 *
 * @return AL_VOID This function does not return a value.
 */
static inline AL_VOID ALOsal_ExitCritical(AL_U64 Flag)
{
    if (AlOsal_In_Intr()) {
        taskEXIT_CRITICAL_FROM_ISR((UBaseType_t)Flag);
    } else {
        taskEXIT_CRITICAL();
    }
}

/*----------------------------------------------*
 * Critical API.*
 *----------------------------------------------*/
/**
 *
 * This function puts the calling thread to sleep for the specifiednduration if the scheduler is started
 * and the current context is a thread context (i.e., not in a critical section). If it is currently
 * in a critical section, the function returns immediately without doing anything.
 *
 * @param Time The amount of time, in ticks, for which the thread should sleep.
 *
 * @return AL_VOID This function does not return a value.
 */
static inline AL_VOID AlOsal_Sleep(AL_U32 Time)
{
    volatile uint32_t criticalNesting =
    #if defined(__riscv)
        uxCriticalNesting;
    #else
        ullCriticalNesting;
    #endif

    if (criticalNesting == 0) {
        vTaskDelay(Time);
    } else {
        return;
    }
}


#endif
#endif
#ifndef USE_RTOS

/*----------------------------------------------*
 * Semaphore API.*
 *----------------------------------------------*/

#define AL_WAITFOREVER          (AL_U32)(-1UL)
#define AL_WAITING_NO           (0)
typedef struct
{
  volatile AL_S32 count;
}AL_Semaphore;
typedef volatile AL_Semaphore* AL_Semaphore_t;

/**
 *
 * This function initializes the specified semaphore with the givennvalue.
 * The semaphore's count is set to the provided initial value.
 *
 * @param Semaphore Pointer to the semaphore to be initialized.
 * @param Name The name of the semaphore (unused in this implementation).
 * @param Value The initial value to set for the semaphore's count.
 *
 * @return AL_S32 Returns AL_OK if the semaphore is initialized successfully.
 */
static inline AL_S32 AlOsal_Sem_Init(AL_Semaphore_t Semaphore, const char* Name, AL_S32 Value)
{
    AL_UNUSED(Name);

    Semaphore->count = Value;

    return AL_OK;
}

/**
 *
 * This function attempts to take the semaphore, decrementing its count if it is greater than zero.
 * If the semaphore is not available (count is zero) and the timeout period elapses, it returns an error.
 *
 * @param Semaphore Pointer to the semaphore to be taken.
 * @param Timeout The maximum time to wait for the semaphore, in ticks.
 *
 * @return AL_S32 Returns AL_OK if the semaphore was successfully taken,
 *         or an error code if the semaphore could not be taken within the timeout period.
 */
static inline AL_S32 AlOsal_Sem_Take(AL_Semaphore_t Semaphore, AL_U32 Timeout)
{
    AL_WAIT_COND_UNTIL_TIMEOUT((Semaphore->count > 0), Timeout);

    Semaphore->count--;

    return AL_OK;
}

/**
 *
 * This function increases the count of the specified semaphore, allowing other waiting tasks
 * or threads to take it. If the count was previously at its maximum (if any limits are set),
 * this function may need to be modified accordingly.
 *
 * @param Semaphore Pointer to the semaphore to be released.
 *
 * @return AL_S32 Returns AL_OK after the semaphore has been successfully released.
 */
static inline AL_S32 AlOsal_Sem_Release(AL_Semaphore_t Semaphore)
{
    Semaphore->count++;

    return AL_OK;
}

/*----------------------------------------------*
 * MUTEX API.*
 *----------------------------------------------*/

typedef AL_Semaphore AL_Lock;
typedef AL_Semaphore_t AL_Lock_t;

/**
 *
 * This function initializes the specified lock. The lock is prepared for use, though the actual
 * implementation details are not shown here. The Name parameter can be used for debugging or
 * logging purposes but is currently unused in the implementation.
 *
 * @param Lock Pointer to the lock to be initialized.
 * @param Name The name of the lock (currently unused in this implementation).
 *
 * @return AL_S32 Returns AL_OK if the lock is initialized successfully.
 */
static inline AL_S32 AlOsal_Lock_Init(AL_Lock_t Lock, const char* Name)
{
    AL_UNUSED(Name);

    AL_UNUSED(Lock);

    return AL_OK;
}

/**
 *
 * This function attempts to acquire the specified lock. If successful, it prevents other threads
 * from acquiring the same lock until it is released. The Timeout parameter specifies the maximum time
 * to wait for the lock; however, the actual timeout handling is not implemented in this version.
 *
 * @param Lock Pointer to the lock to be taken.
 * @param Timeout The maximum time to wait for the lock, in ticks (currently not used in this implementation).
 *
 * @return AL_S32 Returns AL_OK if the lock is successfully taken.
 */
static inline AL_S32 AlOsal_Lock_Take(AL_Lock_t Lock, AL_U32 Timeout)
{
    AL_UNUSED(Timeout);

    AL_UNUSED(Lock);

    return AL_OK;
}

/**
 *
 * This function releases the specified lock, allowing other threads to acquire it.
 * The implementation does not include any actual locking mechanism.
 *
 * @param Lock Pointer to the lock to be released.
 *
 * @return AL_S32 Returns AL_OK after successfully releasing the lock.
 */
static inline AL_S32 AlOsal_Lock_Release(AL_Lock_t Lock)
{
    AL_UNUSED(Lock);

    return AL_OK;
}

/*----------------------------------------------*
 * MailBox API.*
 *----------------------------------------------*/

typedef struct
{
    AL_U64          Msg;
    AL_S32          size;
    volatile AL_S16 entry;                         /**< index of messages in msg_pool */
} AL_MailBox;
typedef volatile AL_MailBox*  AL_MailBox_t;

/**
 *
 * This function initializes the specified mailbox. It sets the message field to 0,
 * the size to 1 (indicating that it can hold one message), and marks the entry as empty.
 * The Name parameter can be used for debugging purposes but is currently unused in this implementation.
 *
 * @param MailBox Pointer to the mailbox to be initialized.
 * @param Name The name of the mailbox (currently unused in this implementation).
 *
 * @return AL_S32 Returns AL_OK if the mailbox is initialized successfully.
 */
static inline AL_S32 AlOsal_Mb_Init(AL_MailBox_t MailBox, const char* Name)
{
    AL_UNUSED(Name);
    MailBox->Msg   = 0;
    MailBox->size  = 1;
    MailBox->entry = 0;

    return AL_OK;
}

/**
 *
 * This function places a message into the specified mailbox. It copies the message value
 * to the mailbox's Msg field and marks the mailbox as having a message ready to be received.
 * The Msg parameter must be a pointer to a value of type AL_U64.
 *
 * @param MailBox Pointer to the mailbox where the message will be sent.
 * @param Msg Pointer to the message to be sent (must be of type AL_U64).
 *
 * @return AL_S32 Returns AL_OK if the message is sent successfully.
 */
static inline AL_S32 AlOsal_Mb_Send(AL_MailBox_t MailBox, AL_VOID * Msg)
{
    MailBox->Msg = *(AL_U64 *)Msg;
    __COMPILER_BARRIER();
    MailBox->entry = 1;

    return AL_OK;
}

/**
 *
 * This function retrieves a message from the specified mailbox. It waits for a message
 * to be available up to the provided Timeout period. If a message is available, it removes
 * the message from the mailbox and returns it to the caller. The Msg parameter must be
 * a pointer to where the received message will be stored.
 *
 * @param MailBox Pointer to the mailbox from which the message will be received.
 * @param Msg Pointer to where the received message will be stored (must be of type AL_U64).
 * @param Timeout Maximum time to wait for a message, in ticks.
 *
 * @return AL_S32 Returns AL_OK if a message is successfully received,
 *         or AL_ERR_UNAVAILABLE if no message is available before timeout.
 */
static inline AL_S32 AlOsal_Mb_Receive(AL_MailBox_t MailBox, AL_VOID* Msg, AL_U32 Timeout)
{
    AL_U32 flag = AL_WAIT_COND_UNTIL_TIMEOUT((MailBox->entry == 1), Timeout);

    if (flag == AL_TRUE) {
        MailBox->entry = 0;
        __COMPILER_BARRIER();
        *(AL_U64 *)Msg = MailBox->Msg;
        return AL_OK;
    }

    return AL_ERR_UNAVAILABLE;
}
/*----------------------------------------------------------------------
 * Critical API.
 *----------------------------------------------------------*/
// extern AL_S32 AlIntr_SetLocalInterrupt(AL_FUNCTION state);
// extern AL_S32 AlIntr_SetInterrupt(AL_U32 IntrId, AL_FUNCTION state);
/**
 *
 * This function disables local interrupts and returns the previous state of the interrupt flag.
 * This is used to prevent interrupt handlers from executing while the critical section
 * is being executed, ensuring that shared resources are accessed safely.
 *
 * @return AL_U64 The previous local interrupt state before disabling it.
 */
static inline AL_U64 ALOsal_EnterCritical(AL_VOID)
{
    return AlIntr_SetLocalInterrupt(AL_FUNC_DISABLE);
}

/**
 *
 * This function restores the local interrupt state to the previous value that was returned
 * when entering the critical section. It ensures that interrupts are re-enabled
 * after the critical section has been executed.
 *
 * @param flag The previous interrupt state, as returned by ALOsal_EnterCritical().
 * @return None.
 */
static inline AL_VOID ALOsal_ExitCritical(AL_U64 flag)
{
    AL_UNUSED(flag);
    (AL_VOID)AlIntr_SetLocalInterrupt(AL_FUNC_ENABLE);
}

/*----------------------------------------------*
 * Critical API for specific devices*
 *----------------------------------------------*/

/**
 *
 * This function disables the specified device interrupt if the provided condition is true.
 * This is used when accessing device-specific resources that should not be interrupted by the device's interrupt handlers.
 *
 * @param DevIntrId The identifier of the device interrupt to disable.
 * @param Condition A boolean value that determines whether to disable the interrupt (true) or not (false).
 * @return None.
 */
static inline AL_VOID AlOsal_EnterDevCtritical(AL_U32 DevIntrId, AL_BOOL Condition)
{
    if (Condition) {
        AlIntr_SetInterrupt(DevIntrId, AL_FUNC_DISABLE);
    }
}

/**
 *
 * This function enables the specified device interrupt if the provided condition is true.
 * It is used to allow the device to generate interrupts again after the critical section has been executed.
 *
 * @param DevIntrId The identifier of the device interrupt to enable.
 * @param Condition A boolean value that determines whether to enable the interrupt (true) or not (false).
 * @return None.
 */
static inline AL_VOID AlOsal_ExitDevCtritical(AL_U32 DevIntrId, AL_BOOL Condition)
{
    if (Condition) {
        AlIntr_SetInterrupt(DevIntrId, AL_FUNC_ENABLE);
    }
}

/**
 *
 * This function suspends the execution of the current task for the specified number of milliseconds.
 * It is typically used to yield processor time or to introduce delays in task execution.
 *
 * @param Msec The amount of time to sleep, in milliseconds.
 * @return None.
 */
static inline AL_VOID AlOsal_Sleep(AL_U32 Msec)
{
    AlSys_MDelay(Msec);
}

#endif
#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* AL_OSAL_H */


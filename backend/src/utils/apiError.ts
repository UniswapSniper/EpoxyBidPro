export class ApiError extends Error {
  public readonly statusCode: number;
  public readonly isOperational: boolean;
  public readonly details?: unknown;

  constructor(statusCode: number, message: string, details?: unknown, isOperational = true) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = isOperational;
    this.details = details;
    Object.setPrototypeOf(this, new.target.prototype);
    Error.captureStackTrace(this, this.constructor);
  }

  static badRequest(message: string, details?: unknown): ApiError {
    return new ApiError(400, message, details);
  }

  static unauthorized(message = 'Unauthorized'): ApiError {
    return new ApiError(401, message);
  }

  static forbidden(message = 'Forbidden'): ApiError {
    return new ApiError(403, message);
  }

  static notFound(resource = 'Resource'): ApiError {
    return new ApiError(404, `${resource} not found`);
  }

  static conflict(message: string): ApiError {
    return new ApiError(409, message);
  }

  static tooManyRequests(message = 'Too many requests'): ApiError {
    return new ApiError(429, message);
  }

  static internal(message = 'Internal server error'): ApiError {
    return new ApiError(500, message, undefined, false);
  }
}

/**
 * Standard success response shape
 */
export function successResponse<T>(
  data: T,
  meta?: Record<string, unknown>
): { success: true; data: T; meta?: Record<string, unknown> } {
  return { success: true, data, ...(meta && { meta }) };
}

/**
 * Standard paginated response shape
 */
export function paginatedResponse<T>(
  data: T[],
  total: number,
  page: number,
  limit: number
): {
  success: true;
  data: T[];
  meta: { total: number; page: number; limit: number; totalPages: number };
} {
  return {
    success: true,
    data,
    meta: {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    },
  };
}

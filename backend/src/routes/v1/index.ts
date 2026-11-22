import { Router } from 'express';
import healthRoutes from './health.routes';
import {
  createAuthRouter,
  createPersistentAuthService,
  createPersistentEmailAuthService,
  createPersistentPasswordAuthService,
} from '../../modules/auth/auth.routes';
import { getAuthRepositoryMode } from '../../config/runtime';

const router = Router();

// Mount feature sub-routers under /api/v1
router.use('/health', healthRoutes);

// Persistent local auth is restricted to the disposable test database.
const authRouter = (() => {
  if (getAuthRepositoryMode() === 'development') {
    return createAuthRouter();
  }
  const authService = createPersistentAuthService();
  return createAuthRouter({
    authService,
    emailAuthService: createPersistentEmailAuthService(),
    passwordAuthService: createPersistentPasswordAuthService(
      undefined,
      authService
    ),
  });
})();

router.use('/auth', authRouter);

// Future modular routers will be mounted here:
// router.use('/appointments', appointmentRoutes);

export default router;

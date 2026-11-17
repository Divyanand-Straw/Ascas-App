import { Router } from 'express';
import healthRoutes from './health.routes';

const router = Router();

// Mount feature sub-routers under /api/v1
router.use('/health', healthRoutes);

// Future modular routers will be mounted here:
// router.use('/auth', authRoutes);
// router.use('/appointments', appointmentRoutes);

export default router;


package com.devops.lab.spring_petclinic_devops;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.springframework.boot.test.context.SpringBootTest;

@SpringBootTest
class SpringPetclinicDevopsApplicationTests {

	@Test
	void contextLoads() {
	}
	@Test
	void testGetPetsRetornaMensaje() {
		// 1. Instanciamos tu controlador
		PetController controller = new PetController();

		// 2. Ejecutamos tu método normal
		String respuesta = controller.getPets();

		// 3. Verificamos que devuelva el texto correcto
		assertTrue(respuesta.contains("API de mi proyecto DevOps"));
	}

	@Test
	void testCausarErrorLanzaExcepcion() {
		// 1. Instanciamos tu controlador
		PetController controller = new PetController();

		// 2. Ejecutamos tu método que forzaste a fallar
		Exception exception = assertThrows(RuntimeException.class, () -> {
			controller.causarError(); // Aquí usamos tu método real
		});

		// 3. Verificamos que contenga la palabra clave de tu error
		assertTrue(exception.getMessage().contains("Grafana"));
	}
	@Test
	void testMainMethod() {
		// Ejecutamos el método main directamente para que JaCoCo lo marque como probado.
		// Le pasamos el argumento --server.port=0 para que use un puerto libre aleatorio
		// y no cause conflictos de puerto ocupado.
		SpringPetclinicDevopsApplication.main(new String[]{"--server.port=0"});
	}
}

package staff;

import java.rmi.Naming;
import java.time.LocalDate;
import java.util.Set;

import hotel.BookingDetail;
import hotel.BookingManagerInterface;

public class BookingClient extends AbstractScriptedSimpleTest {

    private BookingManagerInterface bm = null;

    public static void main(String[] args) throws Exception {
        BookingClient client = new BookingClient();
        client.run();
    }

    public BookingClient() {
        try {
            bm = (BookingManagerInterface) Naming.lookup(
                "rmi://yigit.switzerlandnorth.cloudapp.azure.com:1099/BookingManager"
            );
        } catch (Exception exp) {
            exp.printStackTrace();
        }
    }

    @Override
    public boolean isRoomAvailable(Integer roomNumber, LocalDate date) {
        try {
            return bm.isRoomAvailable(roomNumber, date);
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }

    @Override
    public void addBooking(BookingDetail bookingDetail) throws Exception {
        if (isRoomAvailable(bookingDetail.getRoomNumber(), bookingDetail.getDate())) {
            bm.addBooking(bookingDetail);
        }
    }

    @Override
    public Set<Integer> getAvailableRooms(LocalDate date) {
        try {
            return bm.getAvailableRooms(date);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    @Override
    public Set<Integer> getAllRooms() {
        try {
            return bm.getAllRooms();
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }
}
